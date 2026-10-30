# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{13..14} )

inherit toolchain-funcs desktop python-any-r1

DESCRIPTION="Fast and accurate Sega 8-bit and 16-bit emulator"
HOMEPAGE="https://www.retrodev.com/blastem/"
SRC_URI="https://www.retrodev.com/repos/blastem/archive/2b2a182f4522.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="opengl wayland X"

RDEPEND="
	media-libs/libsdl2[joystick,opengl?]
	virtual/zlib
	opengl? ( virtual/opengl )
	wayland? ( dev-libs/wayland )
	X? ( x11-libs/libX11 x11-libs/libXext )
"
DEPEND="${RDEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	dev-build/make
"

S="${WORKDIR}/blastem-2b2a182f4522"

src_prepare() {
	default
	tc-export CC
}

src_compile() {
	emake
}

src_install() {
	dobin blastem

	insinto /usr/share/${PN}
	doins -r shaders default.cfg rom.db

	dodoc README CHANGELOG
}
