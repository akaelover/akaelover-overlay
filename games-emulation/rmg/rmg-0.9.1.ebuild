# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs xdg

MY_PN="${PN^^}"
MY_P="${MY_PN}-${PV}"
DESCRIPTION="Rosalie's Mupen GUI"
HOMEPAGE="https://github.com/Rosalie241/RMG"
if [[ "${PV}" == *9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Rosalie241/${MY_PN}.git"
else
	SRC_URI="
		https://github.com/Rosalie241/${MY_PN}/archive/refs/tags/v${PV}.tar.gz
			-> ${P}.tar.gz
	"
	S="${WORKDIR}/${MY_P}"
	KEYWORDS="~amd64"
fi

LICENSE="
	BSD-2 CC0-1.0 GPL-2 GPL-3 MIT ZLIB public-domain
	angrylion-plugin? ( XMAME )
"
SLOT="0"
IUSE="angrylion-plugin dynarec netplay"

# Desde 0.9.1 ya no trae SDL3_net empaquetado: con netplay lo busca en el
# sistema por pkg-config (sdl3-net)
DEPEND="
	dev-libs/hidapi
	dev-libs/libusb:1
	dev-qt/qtbase:6[dbus,gui,opengl,vulkan,widgets]
	dev-qt/qtsvg:6
	app-arch/zstd:=
	media-libs/freetype
	media-libs/libpng:=
	media-libs/libsamplerate
	media-libs/libsdl3[opengl,vulkan]
	media-libs/speexdsp
	virtual/minizip:=
	virtual/opengl
	netplay? (
		dev-qt/qtwebsockets:6
		media-libs/sdl3-net
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
	dynarec? ( dev-lang/nasm )
"

src_prepare() {
	# Código de 3rdParty que no se usa - https://bugs.gentoo.org/959468
	rm -r "${S}"/Source/3rdParty/imgui/examples || die
	rm -r "${S}"/Source/3rdParty/mupen64plus-rsp-parallel/win32 || die

	# No instalar el plugin con licencia XMAME si no se pide
	if ! use angrylion-plugin; then
		rm -r "${S}"/Source/3rdParty/mupen64plus-video-angrylion-plus || die
	fi

	# Fuera los binarios precompilados (libvosk.so para VRU)
	rm -r "${S}"/Source/3rdParty/vosk-api || die

	# GLideNHQ busca zstd con su configuración de CMake (zstdConfig.cmake), que el
	# zstd de Gentoo (compilado con meson) no instala: se busca por pkg-config
	sed -e 's/FIND_PACKAGE( zstd REQUIRED )/find_package(PkgConfig REQUIRED)\n    pkg_check_modules(ZSTD REQUIRED libzstd)/' \
		-i "${S}"/Source/3rdParty/mupen64plus-video-GLideN64/src/GLideNHQ/CMakeLists.txt || die

	# Salida detallada de los make(1) de los plugins
	sed -e 's/CC=/V=1 CC=/' -i "${S}"/Source/3rdParty/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	export PKG_CONFIG="$(tc-getPKG_CONFIG)"

	local mycmakeargs=(
		-DAPPIMAGE_UPDATER=OFF
		-DNETPLAY=$(usex netplay)
		-DNO_ASM=$(usex dynarec OFF ON)
		-DPORTABLE_INSTALL=OFF
		-DUPDATER=OFF
		-DUSE_ANGRYLION=$(usex angrylion-plugin)
		-DUSE_CCACHE=OFF
		-DVRU=OFF # binarios precompilados
	)

	cmake_src_configure
}
