# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

MY_PV="${PV:0:4}-${PV:4:2}-${PV:6:2}"

DESCRIPTION="Clock Signal: latency-hating emulator of 8- and 16-bit platforms"
HOMEPAGE="https://github.com/TomHarte/CLK"
SRC_URI="https://github.com/TomHarte/CLK/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/CLK-${MY_PV}"

LICENSE="MIT roms? ( freedist )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="qt6 roms"

RDEPEND="
	virtual/opengl
	virtual/zlib:=
	qt6? (
		dev-qt/qtbase:6[gui,opengl,widgets,X]
		dev-qt/qtmultimedia:6
		x11-libs/libX11
	)
	!qt6? ( media-libs/libsdl2[opengl,sound,video] )
"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DCLK_UI=$(usex qt6 Qt SDL)
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
	dodoc README.md BUILD.md

	# La version SDL busca las ROMs en /usr/share/CLK/<sistema>/.
	# Se instalan siempre los readme.txt (dicen que fichero va en cada carpeta)
	# y, con USE=roms, las ROMs redistribuibles que trae el propio repositorio
	# (Amstrad CPC, ZX Spectrum, ZX80/81, Sinclair QL, BIOS libres de PC).
	insinto /usr/share/CLK
	if use roms; then
		doins -r ROMImages/.
	else
		local f
		while IFS= read -r -d '' f; do
			insinto "/usr/share/CLK/$(dirname "${f#ROMImages/}")"
			doins "${f}"
		done < <(find ROMImages -name '*.txt' -print0 || die)
	fi
}

pkg_postinst() {
	elog "Algunas maquinas necesitan las ROMs originales, que no se incluyen."
	if ! use qt6; then
		elog "Ponlas en /usr/share/CLK/<sistema>/ (o usa --rompath=~/ROMs);"
		elog "el readme.txt de cada carpeta indica los nombres de fichero."
	else
		elog "La version Qt las busca en <AppDataLocation>/ROMImages/<sistema>/,"
		elog "p. ej. ~/.local/share/clksignal/ROMImages/<sistema>/."
	fi
}
