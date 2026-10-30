# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake xdg

DESCRIPTION="Emulador multisistema centrado en la precision (sucesor de higan)"
HOMEPAGE="https://ares-emu.net/ https://github.com/ares-emulator/ares"
SRC_URI="https://github.com/ares-emulator/ares/releases/download/v${PV}/ares-source.tar.gz -> ${P}-source.tar.gz"
# El tarball se genera con "git archive" sin prefijo: no lleva carpeta raiz.
S="${WORKDIR}"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="alsa ao lto openal oss +pulseaudio +sdl +udev"
REQUIRED_USE="|| ( alsa ao openal oss pulseaudio sdl )"

RDEPEND="
	virtual/opengl
	x11-libs/gtk+:3[X]
	x11-libs/libX11
	x11-libs/libXrandr
	alsa? ( media-libs/alsa-lib )
	ao? ( media-libs/libao )
	openal? ( media-libs/openal )
	pulseaudio? ( media-libs/libpulse )
	sdl? ( media-libs/libsdl3 )
	udev? ( virtual/libudev:= )
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	local mycmakeargs=(
		# Sin esto descarga dependencias precompiladas de ares-deps.
		-DARES_SKIP_DEPS=ON
		-DARES_VERSION_OVERRIDE="v${PV}"
		# Respetar CFLAGS de make.conf en vez de forzar -march=native.
		-DARES_BUILD_LOCAL=OFF
		-DARES_ENABLE_MINIMUM_CPU=OFF
		-DENABLE_CCACHE=OFF
		-DENABLE_IPO=$(usex lto)
		-DARES_BUILD_OPTIONAL_TARGETS=OFF
		# librashader y slang-shaders no estan en el arbol de Gentoo; si
		# instalas librashader por tu cuenta, ares lo carga en tiempo de ejecucion.
		-DARES_ENABLE_LIBRASHADER=OFF
		-DARES_BUNDLE_SHADERS=OFF
		-DARES_ENABLE_ALSA=$(usex alsa)
		-DARES_ENABLE_AO=$(usex ao)
		-DARES_ENABLE_OPENAL=$(usex openal)
		-DARES_ENABLE_OSS=$(usex oss)
		-DARES_ENABLE_PULSEAUDIO=$(usex pulseaudio)
		-DARES_ENABLE_SDL=$(usex sdl)
		-DARES_ENABLE_UDEV=$(usex udev)
	)
	cmake_src_configure
}
