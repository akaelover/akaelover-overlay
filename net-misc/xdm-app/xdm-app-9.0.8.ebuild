# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop java-pkg-2 xdg

DESCRIPTION="Xtreme Download Manager: download accelerator and video downloader"
HOMEPAGE="https://xtremedownloadmanager.com https://github.com/subhra74/xdm"
SRC_URI="https://github.com/subhra74/xdm/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/xdm-${PV}"

# xdm-app: GPL-3; xdm-core y el jar con dependencias (Kotlin, FlatLaf, OkHttp,
# kotlinx-serialization): Apache-2.0
LICENSE="GPL-3 Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Maven descarga de Maven Central los plugins y las dependencias (Kotlin,
# FlatLaf, OkHttp...) durante src_compile, así que necesita red.
# Los tests están desactivados en el propio pom.xml.
RESTRICT="network-sandbox test"

BDEPEND="dev-java/maven-bin:3.9"
# xdm-app se compila con target Java 25 (usa java.lang.foreign) y el pom.xml
# exige un toolchain JDK 25 exacto.
DEPEND="virtual/jdk:25"
RDEPEND=">=virtual/jre-25:*"

src_compile() {
	# Kotlin crea ~/.kotlin y Maven escribe en ~/.m2. Java no usa $HOME sino
	# user.home (sacado de /etc/passwd → /var/lib/portage/home, fuera del
	# sandbox), así que hay que fijarlo explícitamente para la JVM de Maven.
	export HOME="${T}/home"
	mkdir -p "${HOME}" || die
	export MAVEN_OPTS="-Duser.home=${HOME}"

	# maven-toolchains-plugin (select-jdk-toolchain) y exec-maven-plugin buscan
	# un JDK "25" en toolchains.xml: apuntamos al JDK que eligió java-pkg-2.
	cat > "${T}/toolchains.xml" <<-EOF || die
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
	EOF

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
	java-pkg_dolauncher xdm-app \
		--main xdm.app.AppMain \
		--java_args "--enable-native-access=ALL-UNNAMED -XX:+UseCompactObjectHeaders -Djpackage.app-path=${EPREFIX}/usr/bin/xdm-app"

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

	elog "Igual que los paquetes oficiales, en el primer arranque XDM activa el"
	elog "inicio automático (~/.config/autostart/xdm-app.desktop). Se puede"
	elog "desactivar desde los ajustes de la aplicación."
	elog
	elog "La extensión del navegador está en:"
	elog "  https://github.com/subhra74/xdm/tree/master/browser-extension"
}
