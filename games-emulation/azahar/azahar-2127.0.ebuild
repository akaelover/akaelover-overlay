# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic git-r3 multilib xdg

DESCRIPTION="Nintendo 3DS emulator (unified fork of Citra and PabloMK7's Citra)"
HOMEPAGE="https://azahar-emu.org/ https://github.com/azahar-emu/azahar"
EGIT_REPO_URI="https://github.com/azahar-emu/azahar.git"
if [[ ${PV} != 9999 ]]; then
	EGIT_COMMIT="${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-2+"
SLOT="0"
IUSE="+cubeb ffmpeg lto +openal room +vulkan"

# El resto de librerias (boost, fmt, dynarmic, cryptopp, SDL2, libressl,
# glslang, sirit...) van empaquetadas como submodulos, que es como lo
# compilan y prueban los desarrolladores.
RDEPEND="
	dev-qt/qtbase:6[concurrent,dbus,gui,opengl,widgets]
	dev-qt/qtmultimedia:6
	media-libs/alsa-lib
	media-libs/libpulse
	virtual/libudev:=
	virtual/opengl
	x11-libs/libX11
	ffmpeg? ( media-video/ffmpeg-compat:7= )
	vulkan? ( media-libs/vulkan-loader )
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-qt/qttools:6[linguist]
	virtual/pkgconfig
"

src_prepare() {
	# Sin esto la version sale como "0" / "UNKNOWN" en la ventana.
	if [[ ${PV} != 9999 ]]; then
		echo "${EGIT_VERSION}" > GIT-COMMIT || die
		echo "${PV}" > GIT-TAG || die
	fi
	cmake_src_prepare
}

src_configure() {
	# Desde la 2127.0 el volcado de video enlaza FFmpeg y exige la 7.x exacta
	# (libavutil 59); en Gentoo esa es ffmpeg-compat:7, que va en su propio
	# prefijo, fuera de la ruta normal de pkg-config y del enlazador.
	if use ffmpeg; then
		local ffdir="${ESYSROOT}/usr/lib/ffmpeg7/$(get_libdir)"
		export PKG_CONFIG_PATH="${ffdir}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
		append-ldflags "-Wl,-rpath,${EPREFIX}/usr/lib/ffmpeg7/$(get_libdir)"
	fi

	local mycmakeargs=(
		# Sin esto intenta descargar Qt con aqt en plena compilacion.
		-DUSE_SYSTEM_QT=ON
		-DENABLE_QT=ON
		-DENABLE_QT_TRANSLATION=ON
		-DENABLE_QT_UPDATE_CHECKER=OFF
		-DENABLE_SDL2=ON
		-DENABLE_TESTS=OFF
		-DENABLE_LIBRETRO=OFF
		-DENABLE_DISCORD_RPC=OFF
		-DENABLE_CCACHE=OFF
		-DENABLE_FFMPEG=$(usex ffmpeg)
		-DENABLE_CUBEB=$(usex cubeb)
		-DENABLE_OPENAL=$(usex openal)
		-DENABLE_VULKAN=$(usex vulkan)
		-DENABLE_OPENGL=ON
		-DENABLE_ROOM=$(usex room)
		-DENABLE_ROOM_STANDALONE=$(usex room)
		-DENABLE_LTO=$(usex lto)
		-DENABLE_NATIVE_OPTIMIZATION=OFF
		-DCITRA_WARNINGS_AS_ERRORS=OFF
	)
	cmake_src_configure
}
