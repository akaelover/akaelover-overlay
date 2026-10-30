
# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="SDL2-based emulator for the NEC PC-8801 (PC-88)"
HOMEPAGE="https://github.com/bubio/QUASI88"

EGIT_REPO_URI="https://github.com/bubio/QUASI88.git"

LICENSE="BSD"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND="
	media-libs/libsdl2
"
RDEPEND="${DEPEND}"
BDEPEND="
	dev-build/cmake
	dev-build/ninja
"

src_configure() {
	local mycmakeargs=(
		-DUSE_SOUND=ON
		-DUSE_FMGEN=ON
		-DSUPPORT_DOUBLE=ON
		-DUSE_MONITOR=ON
		-DMACOSX_STANDALONE_APP_BUNDLE=OFF
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	dodoc README.md

	if [[ -d doc ]]; then
		dodoc doc/*
	fi
}
