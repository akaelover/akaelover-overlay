# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop java-pkg-2 xdg

# JetBrains Runtime de los paquetes oficiales (packaging/jdk.properties):
# el único JDK con el toolkit nativo de Wayland (sun.awt.wl.WLToolkit).
JBR_PV="25.0.4.1"
JBR_BUILD="b635.70"

DESCRIPTION="Xtreme Download Manager: download accelerator and video downloader"
HOMEPAGE="https://xtremedownloadmanager.com https://github.com/subhra74/xdm"
# 9.0.9 y 9.0.10 llevaban "v"; 9.0.11 ha vuelto a ir sin ella
SRC_URI="
	https://github.com/subhra74/xdm/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	jbr? (
		amd64? ( https://cache-redirector.jetbrains.com/intellij-jbr/jbr-${JBR_PV}-linux-x64-${JBR_BUILD}.tar.gz )
	)
"
S="${WORKDIR}/xdm-${PV}"

# xdm-app: GPL-3; xdm-core y el jar con dependencias (Kotlin, FlatLaf, OkHttp,
# kotlinx-serialization, Conscrypt): Apache-2.0; JBR: GPL-2 con classpath exception
LICENSE="GPL-3 Apache-2.0 jbr? ( GPL-2-with-classpath-exception )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+jbr"

# Maven descarga de Maven Central los plugins y las dependencias (Kotlin,
# FlatLaf, OkHttp...) durante src_compile, así que necesita red.
# Los tests están desactivados en el propio pom.xml.
RESTRICT="network-sandbox test"

BDEPEND="dev-java/maven-bin:3.9"
# xdm-app se compila con target Java 25 (usa java.lang.foreign) y el pom.xml
# exige un toolchain JDK 25 exacto.
DEPEND="virtual/jdk:25"
# Con USE=jbr se ejecuta con la JBR incluida y no hace falta otra JRE.
# Sus libs AWT/Wayland se cargan del sistema.
RDEPEND="
	jbr? (
		dev-libs/wayland
		media-libs/alsa-lib
		media-libs/fontconfig
		media-libs/freetype
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXtst
		x11-libs/libxkbcommon
	)
	!jbr? ( >=virtual/jre-25:* )
"

QA_PREBUILT="opt/${PN}/jbr/*"

src_unpack() {
	unpack ${P}.tar.gz
	if use jbr; then
		mkdir "${WORKDIR}/jbr-unpack" || die
		cd "${WORKDIR}/jbr-unpack" || die
		local jbr_arch
		case ${ARCH} in
			amd64) jbr_arch=x64 ;;
			*) die "JBR no disponible para ${ARCH}" ;;
		esac
		unpack jbr-${JBR_PV}-linux-${jbr_arch}-${JBR_BUILD}.tar.gz
	fi
}

src_compile() {
	# Kotlin crea ~/.kotlin y Maven escribe en ~/.m2. Java no usa $HOME sino
	# user.home (sacado de /etc/passwd → /var/lib/portage/home, fuera del
	# sandbox), así que hay que fijarlo explícitamente para la JVM de Maven.
	export HOME="${T}/home"
	mkdir -p "${HOME}" || die
	export MAVEN_OPTS="-Duser.home=${HOME}"

	# maven-toolchains-plugin (select-jdk-toolchain) y exec-maven-plugin buscan
	# un JDK "25" en toolchains.xml: apuntamos al JDK que eligió java-pkg-2.
	cat > "${T}/toolchains.xml" <<-EOT || die
		<?xml version="1.0" encoding="UTF-8"?>
		<toolchains>
			<toolchain>
				<type>jdk</type>
				<provides>
					<version>25</version>
				</provides>
				<configuration>
					<jdkHome>${JAVA_HOME}</jdkHome>
				</configuration>
			</toolchain>
		</toolchains>
	EOT

	mvn-3.9 --batch-mode --no-transfer-progress \
		-Dmaven.repo.local="${WORKDIR}/m2" \
		-Dkotlin.compiler.daemon=false \
		--toolchains "${T}/toolchains.xml" \
		-DskipTests \
		-pl xdm-app -am \
		package || die "mvn package failed"
}

src_install() {
	# Jar "jar-with-dependencies" generado por maven-assembly-plugin
	java-pkg_newjar xdm-app/target/xdm-app.jar

	# - enable-native-access: FlatLaf carga una librería JNI (JDK 22+ avisa si no).
	# - UseCompactObjectHeaders: el mismo flag que usan los paquetes oficiales con JDK 25+.
	# - jpackage.app-path: la app lo usa para saber qué comando poner en
	#   ~/.config/autostart (como en los .deb/.rpm oficiales); sin él escribiría
	#   "java -jar /usr/share/xdm-app/lib/xdm-app.jar".
	local java_args="--enable-native-access=ALL-UNNAMED -XX:+UseCompactObjectHeaders -Djpackage.app-path=${EPREFIX}/usr/bin/xdm-app"

	if use jbr; then
		local jbrdir
		jbrdir=$(find "${WORKDIR}/jbr-unpack" -mindepth 1 -maxdepth 1 -type d | head -n1) || die
		[[ -x ${jbrdir}/bin/java ]] || die "No se encuentra bin/java en la JBR"
		# cp -a conserva permisos y enlaces de la JBR (doins quitaría el +x)
		dodir /opt/${PN}
		cp -a "${jbrdir}" "${ED}/opt/${PN}/jbr" || die

		# Lanzador propio: java-pkg_dolauncher siempre usa la JVM de java-config
		cat > "${T}/xdm-app" <<-EOT || die
			#!/bin/sh
			exec "${EPREFIX}/opt/${PN}/jbr/bin/java" ${java_args} \\
				-cp "${EPREFIX}/usr/share/${PN}/lib/xdm-app.jar" xdm.app.AppMain "\$@"
		EOT
		dobin "${T}/xdm-app"
	else
		java-pkg_dolauncher xdm-app \
			--main xdm.app.AppMain \
			--java_args "${java_args}"
	fi

	local size
	for size in 16 24 32 48 64 128 256 512; do
		newicon -s ${size} xdm-app/src/main/resources/images/xdm-logo-${size}.png xdm-app.png
	done

	# El .desktop oficial apunta a /opt/xdm-app/bin/xdm-app
	sed -e 's|^Exec=.*|Exec=xdm-app %U|' \
		packaging/linux/xdm-app.desktop > "${T}/xdm-app.desktop" || die
	domenu "${T}/xdm-app.desktop"

	einstalldocs
}

pkg_preinst() {
	java-pkg-2_pkg_preinst
	xdg_pkg_preinst
}

pkg_postinst() {
	xdg_pkg_postinst

	if use jbr; then
		elog "XDM usa el JetBrains Runtime incluido (/opt/${PN}/jbr): en una sesión"
		elog "Wayland puede ejecutarse como app Wayland nativa (Ajustes → Avanzado →"
		elog "Native Wayland, activado por defecto)."
	fi
	elog
	elog "Igual que los paquetes oficiales, en el primer arranque XDM activa el"
	elog "inicio automático (~/.config/autostart/xdm-app.desktop). Se puede"
	elog "desactivar desde los ajustes de la aplicación."
	elog
	elog "Extensión para Firefox (XDM Browser Monitor v9+):"
	elog "  https://xtremedownloadmanager.com/extension/firefox/"
}
