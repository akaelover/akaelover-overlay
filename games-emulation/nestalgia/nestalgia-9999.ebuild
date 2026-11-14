# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop git-r3

DESCRIPTION="Cross-platform, high-accuracy NES/Famicom emulator in Kotlin (port of Mesen)"
HOMEPAGE="https://tiagohm.github.io/nestalgia https://github.com/tiagohm/nestalgia"
EGIT_REPO_URI="https://github.com/tiagohm/nestalgia.git"

LICENSE="GPL-3"
SLOT="0"

# Gradle descarga sus dependencias (Kotlin, JavaFX, Jamepad...) al compilar
RESTRICT="network-sandbox strip test"

# Gradle 8.10.2 (el del wrapper) solo arranca con JDK <= 23: compilamos con el 21
BDEPEND="|| ( dev-java/openjdk:21 dev-java/openjdk-bin:21 )"
RDEPEND="
	>=virtual/jre-21:*
	x11-libs/gtk+:3
	x11-libs/libXtst
	x11-libs/libXt
"

src_compile() {
	local jdk
	for jdk in "${BROOT}"/usr/$(get_libdir)/openjdk-21 "${BROOT}"/opt/openjdk-bin-21*; do
		[[ -x ${jdk}/bin/javac ]] && break
	done
	[[ -x ${jdk}/bin/javac ]] || die "no se encontró el JDK 21"
	export JAVA_HOME="${jdk}"
	export GRADLE_USER_HOME="${T}/gradle"
	# Que Java/Kotlin no intenten escribir en el HOME de portage (sandbox)
	export JAVA_TOOL_OPTIONS="-Duser.home=${T}/home"
	mkdir -p "${T}/home" || die

	./gradlew --no-daemon --console=plain \
		-Dorg.gradle.java.home="${JAVA_HOME}" \
		-Pkotlin.user.home="${T}/kotlin" \
		-Pkotlin.compiler.execution.strategy=in-process \
		:desktop:shadowJar || die "gradle falló"
}

src_install() {
	insinto /usr/share/${PN}
	doins desktop/build/libs/nestalgia.jar

	newbin - ${PN} <<-EOF
		#!/bin/sh
		exec java -jar "${EPREFIX}/usr/share/${PN}/nestalgia.jar" "\$@"
	EOF

	make_desktop_entry ${PN} Nestalgia "" "Game;Emulator;"
}
