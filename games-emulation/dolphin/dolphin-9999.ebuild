# Copyright 2026 akaelover
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3 udev xdg

DESCRIPTION="Emulador de GameCube y Wii (versión de desarrollo, rama master)"
HOMEPAGE="https://dolphin-emu.org/ https://github.com/dolphin-emu/dolphin"
EGIT_REPO_URI="https://github.com/dolphin-emu/dolphin.git"
# Se bajan todos los submódulos menos los que solo sirven para Windows/macOS/Android
EGIT_SUBMODULES=(
	'*'
	'-Externals/Qt'
	'-Externals/FFmpeg-bin'
	'-Externals/MoltenVK'
	'-Externals/libadrenotools'
	'-Externals/ANGLE'
)

LICENSE="GPL-2+ Apache-2.0 BSD BSD-2 LGPL-2.1+ MIT MPL-2.0 ZLIB"
SLOT="0"
KEYWORDS=""
IUSE="+alsa discord +evdev +ffmpeg +gui +mgba +pulseaudio +retroachievements +sdl +upnp"
RESTRICT="test"

RDEPEND="
	dev-libs/hidapi
	media-libs/libglvnd[X]
	net-misc/curl
	virtual/libudev:=
	virtual/libusb:1
	x11-libs/libX11
	x11-libs/libXi
	x11-libs/libXrandr
	alsa? ( media-libs/alsa-lib )
	evdev? ( dev-libs/libevdev )
	ffmpeg? ( media-video/ffmpeg:= )
	gui? (
		dev-qt/qtbase:6[gui,widgets]
		dev-qt/qtsvg:6
	)
	pulseaudio? ( media-libs/libpulse )
	sdl? ( media-libs/libsdl3 )
	upnp? ( net-libs/miniupnpc:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-vcs/git
	virtual/pkgconfig
"

src_configure() {
	local mycmakeargs=(
		# Las librerías internas de Dolphin tienen dependencias cíclicas:
		# solo enlazan si son estáticas (cmake.eclass pone ON por defecto)
		-DBUILD_SHARED_LIBS=OFF
		-DDISTRIBUTOR="akaelover-overlay"
		-DENABLE_AUTOUPDATE=OFF
		-DENABLE_ANALYTICS=OFF
		-DENABLE_TESTS=OFF
		-DENABLE_LLVM=OFF
		-DENABLE_LTO=OFF
		-DENABLE_CCACHE=OFF
		-DENABLE_CLI_TOOL=ON
		-DENABLE_NOGUI=ON
		-DENABLE_QT=$(usex gui)
		-DENABLE_ALSA=$(usex alsa)
		-DENABLE_PULSEAUDIO=$(usex pulseaudio)
		-DENABLE_EVDEV=$(usex evdev)
		-DENABLE_SDL=$(usex sdl)
		-DENCODE_FRAMEDUMPS=$(usex ffmpeg)
		-DUSE_UPNP=$(usex upnp)
		-DUSE_DISCORD_PRESENCE=$(usex discord)
		-DUSE_MGBA=$(usex mgba)
		-DUSE_RETRO_ACHIEVEMENTS=$(usex retroachievements)
		# Usa librerías del sistema cuando las encuentra con versión válida
		-DUSE_SYSTEM_LIBS=AUTO
		# ...salvo estas, que en Gentoo suelen ir por delante o por detrás
		# de lo que espera la rama master: mejor las incluidas
		-DUSE_SYSTEM_FMT=OFF
		-DUSE_SYSTEM_GLSLANG=OFF
		-DUSE_SYSTEM_LIBMGBA=OFF
		-DUSE_SYSTEM_MBEDTLS=OFF
		-DUSE_SYSTEM_MINIZIP-NG=OFF
		-DUSE_SYSTEM_SFML=OFF
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Reglas udev para el adaptador de mandos de GameCube y la Wii Bar:
	# se quitan las que haya puesto CMake y se instalan en su sitio correcto
	rm -rf "${ED}"/usr/lib64/udev "${ED}"/usr/lib/udev || die
	if [[ -f Data/51-usb-device.rules ]]; then
		udev_dorules Data/51-usb-device.rules
	fi
}

pkg_postinst() {
	xdg_pkg_postinst
	udev_reload
}

pkg_postrm() {
	xdg_pkg_postrm
	udev_reload
}
