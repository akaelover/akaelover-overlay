# Copyright 2026 Juan Pedro
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="PlayStation 4 emulator (core, without GUI)"
HOMEPAGE="https://shadps4.net https://github.com/shadps4-emu/shadPS4"
EGIT_REPO_URI="https://github.com/shadps4-emu/shadPS4.git"
# Todos los submódulos salvo el Mesa para macOS (KosmicKrisp), que es enorme
# y solo se usa en Apple.
EGIT_SUBMODULES=( '*' '-externals/mesa-kosmickrisp' )

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE="discord"

# Casi todo va incluido (externals/). Esto es lo que necesitan SDL3 y
# openal-soft incluidos para el audio, la entrada y las ventanas.
DEPEND="
	dev-libs/libevdev
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/libpulse
	sys-apps/util-linux
	virtual/jack
	virtual/libudev
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXScrnSaver
	x11-libs/libxkbcommon
"
RDEPEND="${DEPEND}
	media-libs/vulkan-loader
"
BDEPEND="
	dev-util/wayland-scanner
	llvm-core/clang
	virtual/pkgconfig
"

pkg_setup() {
	# El proyecto recomienda Clang (es lo que usan las builds oficiales y CI)
	export CC=clang CXX=clang++
}

src_configure() {
	local mycmakeargs=(
		-DENABLE_UPDATER=OFF
		-DENABLE_DISCORD_RPC=$(usex discord)
		-DENABLE_TESTS=OFF
		-DENABLE_SYSTEM_LIBRARIES=OFF
	)
	cmake_src_configure
}

src_install() {
	dobin "${BUILD_DIR}"/shadps4
	einstalldocs
}

pkg_postinst() {
	elog "Esto instala solo el núcleo (shadps4, por línea de comandos)."
	elog "La interfaz gráfica es un proyecto aparte: shadps4-qtlauncher."
}
