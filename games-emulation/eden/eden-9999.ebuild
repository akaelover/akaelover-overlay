# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cmake git-r3

DESCRIPTION="Nintendo Switch emulator forked from yuzu"
HOMEPAGE="https://eden-emulator.github.io/"
EGIT_REPO_URI="https://git.eden-emu.dev/eden-emu/eden.git"

LICENSE="GPL-3+"
SLOT="0"
IUSE="discord +game-devices-udev +qt6 sdl3"
# El proyecto descarga dependencias durante la compilación
RESTRICT="network-sandbox"

RDEPEND="
	dev-libs/boost:=
	app-arch/brotli
	dev-libs/libfmt
	dev-libs/libusb:1
	dev-cpp/nlohmann_json
	dev-libs/openssl:=
	dev-libs/quazip
	virtual/zlib
	app-arch/zstd
	media-libs/alsa-lib
	media-libs/cubeb
	media-libs/opus
	media-video/ffmpeg
	net-libs/enet
	sys-libs/glibc
	media-libs/zita-alsa-pcmi
	virtual/opengl
	x11-themes/hicolor-icon-theme
	sdl3? ( media-libs/libsdl3 )
	qt6? (
		dev-qt/qtbase:6[gui,widgets]
		dev-qt/qtcharts:6
		dev-qt/qtmultimedia:6
		dev-qt/qttools:6
		dev-qt/qtwebengine:6
	)
	game-devices-udev? ( games-util/game-device-udev-rules )
"

DEPEND="
	${RDEPEND}
	dev-cpp/catch
	dev-util/spirv-headers
	dev-util/vulkan-headers
	dev-util/vulkan-utility-libraries
	dev-lang/nasm
	dev-build/cmake
	dev-build/ninja
	dev-util/opencl-headers
	app-text/doxygen
"

BDEPEND="
	dev-vcs/git
	dev-build/ninja
"

src_configure() {
	local mycmakeargs=(
		-Dhttplib_FORCE_BUNDLED=ON
		-DCMAKE_BUILD_TYPE=Release
		-DUSE_DISCORD_PRESENCE=$(usex discord ON OFF)
		-DYUZU_USE_BUNDLED_FFMPEG=OFF
		-DYUZU_USE_BUNDLED_SDL3=OFF
		-DDiscordRPC_FORCE_BUNDLED=ON
		-DYUZU_USE_BUNDLED_QT=OFF
		-Dxbyak_FORCE_BUNDLED=ON
		-DENABLE_QT_TRANSLATION=$(usex qt6 ON OFF)
		-DYUZU_USE_QT_MULTIMEDIA=$(usex qt6 ON OFF)
		-DYUZU_USE_QT_WEB_ENGINE=$(usex qt6 ON OFF)
		-DYUZU_TESTS=OFF
		-DDYNARMIC_TESTS=OFF
		-DBUILD_TESTING=OFF
		-Wno-dev
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	if [[ -d "${S}/LICENSES" ]]; then
		local file
		for file in "${S}"/LICENSES/*.txt; do
			[[ -f "$file" ]] && insinto /usr/share/licenses/${PN} && doins "$file"
		done
	fi
}
