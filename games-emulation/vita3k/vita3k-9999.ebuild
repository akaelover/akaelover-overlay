# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
CMAKE_BUILD_TYPE="Release"

inherit cmake git-r3 python-any-r1 xdg

DESCRIPTION="Emulador experimental de PlayStation Vita"
HOMEPAGE="https://vita3k.org/ https://github.com/Vita3K/Vita3K"
EGIT_REPO_URI="https://github.com/Vita3K/Vita3K.git"
# Boost solo se usa en cabeceras: se toma la del sistema y no se baja
# el submodulo (que es enorme).
EGIT_SUBMODULES=( '*' '-external/boost' )

LICENSE="GPL-2+ BSD MIT ZLIB Boost-1.0 Apache-2.0 LGPL-2.1+"
# ffmpeg llega como libreria estatica precompilada por el proyecto
# (Vita3K/ffmpeg-core), igual que en sus builds oficiales.
SLOT="0"
IUSE="lto"
RESTRICT="test"

# Casi todo (SDL3, dynarmic, glslang, SPIRV-Cross, fmt, spdlog...) va como
# submodulo; del sistema se usan Qt 6 (>= 6.11), OpenSSL y curl.
RDEPEND="
	>=dev-qt/qtbase-6.11:6[dbus,gui,network,widgets]
	>=dev-qt/qtmultimedia-6.11:6
	>=dev-qt/qtsvg-6.11:6
	dev-libs/openssl:=
	media-libs/vulkan-loader
	net-misc/curl
	sys-apps/dbus
	virtual/zlib:=
"
DEPEND="
	${RDEPEND}
	>=dev-libs/boost-1.82
"
BDEPEND="
	${PYTHON_DEPS}
	>=dev-qt/qttools-6.11:6[linguist]
	app-arch/unzip
	net-misc/curl
	virtual/pkgconfig
"

src_unpack() {
	git-r3_src_unpack

	# external/ffmpeg descarga en el configure un zip precompilado cuyo
	# nombre depende del commit del submodulo (git rev-parse en un arbol
	# sin .git). Lo bajamos aqui, donde hay red, y se coloca luego.
	local store="${EGIT3_STORE_DIR:-${PORTAGE_ACTUAL_DISTDIR:-${DISTDIR}}/git3-src}"
	local gitdir sha
	gitdir=$(find "${store}" -maxdepth 1 -type d -iname '*vita3k_vita3k*' | head -n1)
	[[ -d ${gitdir} ]] || die "no encuentro el clon de Vita3K en ${store}"
	sha=$(git --git-dir="${gitdir}" ls-tree "${EGIT_VERSION}" external/ffmpeg | awk '{print $3}')
	[[ -n ${sha} ]] || die "no se encuentra el commit del submodulo ffmpeg"
	curl -fsSL -o "${WORKDIR}/ffmpeg.zip" \
		"https://github.com/Vita3K/ffmpeg-core/releases/download/${sha:0:7}/ffmpeg-linux-x64.zip" \
		|| die "no se ha podido bajar ffmpeg-linux-x64.zip (${sha:0:7})"
}

src_prepare() {
	# external/CMakeLists.txt exige que todos los submodulos tengan algo
	# dentro, tambien boost aunque se use el del sistema (forzado abajo).
	mkdir -p external/boost || die
	echo "Se usa Boost del sistema" > external/boost/GENTOO-SYSTEM-BOOST || die

	# Version: sin .git en el arbol, los git rev-parse salen vacios.
	sed -i "/^set(VITA3K_OFFICIAL_UPDATE_BUILD 0)/i set(GIT_COUNT 0)\nset(GIT_HASH ${EGIT_VERSION:0:7})\nset(GIT_BRANCH master)" \
		vita3k/CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	mkdir -p "${BUILD_DIR}/external" || die
	cp "${WORKDIR}/ffmpeg.zip" "${BUILD_DIR}/external/ffmpeg.zip" || die

	local mycmakeargs=(
		# Descargaria el SDK privativo de Discord.
		-DUSE_DISCORD_RICH_PRESENCE=OFF
		-DVITA3K_FORCE_SYSTEM_BOOST=ON
		-DBUILD_TESTING=OFF
		# El eclass pone BUILD_SHARED_LIBS=ON; Vita3K enlaza todos sus
		# submodulos como estaticos (si no, libpsvpfsparser.so falla por PIC).
		-DBUILD_SHARED_LIBS=OFF
		# Con GCC, el LTO mezcla los dos spirv.hpp incompatibles (glslang y
		# SPIRV-Cross, ver avisos -Wodr) y se pierden simbolos de glslang al
		# enlazar. Upstream compila con Clang; aqui va desactivado por defecto.
		-DUSE_LTO=$(usex lto RELEASE_ONLY NEVER)
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Los submodulos (fmt, pugixml, spdlog, yaml-cpp...) tienen sus propias
	# reglas de instalacion y meten cabeceras, librerias estaticas y ficheros
	# de cmake/pkgconfig que chocan con los paquetes del sistema. Vita3K va
	# enlazado estaticamente, asi que nada de eso hace falta.
	rm -rf \
		"${ED}"/usr/include \
		"${ED}"/usr/$(get_libdir)/cmake \
		"${ED}"/usr/$(get_libdir)/pkgconfig \
		"${ED}"/usr/share/cmake \
		"${ED}"/usr/share/pkgconfig || die
	find "${ED}" \( -name '*.a' -o -name '*.la' \) -delete || die
	# Si queda algun directorio de librerias vacio, fuera.
	find "${ED}"/usr -depth -type d -empty -delete || die
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "Vita3K necesita el firmware de PS Vita (PSVUPDAT.PUP y PSP2UPDAT.PUP)"
	elog "de la web de Sony; el propio programa lo pide la primera vez."
}
