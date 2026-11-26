# Copyright 2026 akaelover
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

MY_P="SDL_net-release-${PV}"
DESCRIPTION="Simple, cross-platform networking library for SDL3"
HOMEPAGE="https://www.libsdl.org/projects/SDL_net/ https://github.com/libsdl-org/SDL_net"
SRC_URI="https://github.com/libsdl-org/SDL_net/archive/refs/tags/release-${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND=">=media-libs/libsdl3-3.0.0"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DSDLNET_INSTALL=ON
		-DSDLNET_INSTALL_MAN=OFF
		-DSDLNET_SAMPLES=OFF
		-DSDLNET_WERROR=OFF
	)

	cmake_src_configure
}
