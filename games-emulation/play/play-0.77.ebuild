# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake xdg

# Commits de los submódulos en el tag 0.77
FRAMEWORK_COMMIT="587f278917acc0026bf5fc34b39f995fc26bd015"
CODEGEN_COMMIT="a5009f7dca062695b8e5aebbd71e67b4ddfa9251"
NUANCEUR_COMMIT="d96578b5a18edc67a268ed4811f0a035c56de7a0"
LIBCHDR_COMMIT="284e38b6e53e0a7270cc234934e45230ed915a25"
DEPENDENCIES_COMMIT="8a5f6b1dea0b888b5a42b821e79470142bbea4e3"
# Submódulos anidados de Play-Dependencies
GHCFS_COMMIT="2a8b380f8d4e77b389c42a194ab9c70d8e3a0f1e"
XXHASH_COMMIT="e626a72bc2321cd320e953a0ccf1584cad60f363"
ZLIB_COMMIT="5a82f71ed1dfc0bec044d9702463dbdf84ea3b71"
ZSTD_COMMIT="f8745da6ff1ad1e7bab384bd1f9d742439278e99"

DESCRIPTION="Play! - PlayStation 2 emulator"
HOMEPAGE="https://purei.org/ https://github.com/jpd002/Play-"
SRC_URI="
	https://github.com/jpd002/Play-/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/jpd002/Play--Framework/archive/${FRAMEWORK_COMMIT}.tar.gz -> ${PN}-Framework-${FRAMEWORK_COMMIT}.tar.gz
	https://github.com/jpd002/Play--CodeGen/archive/${CODEGEN_COMMIT}.tar.gz -> ${PN}-CodeGen-${CODEGEN_COMMIT}.tar.gz
	https://github.com/jpd002/Nuanceur/archive/${NUANCEUR_COMMIT}.tar.gz -> ${PN}-Nuanceur-${NUANCEUR_COMMIT}.tar.gz
	https://github.com/jpd002/libchdr/archive/${LIBCHDR_COMMIT}.tar.gz -> ${PN}-libchdr-${LIBCHDR_COMMIT}.tar.gz
	https://github.com/jpd002/Play-Dependencies/archive/${DEPENDENCIES_COMMIT}.tar.gz -> ${PN}-Dependencies-${DEPENDENCIES_COMMIT}.tar.gz
	https://github.com/gulrak/filesystem/archive/${GHCFS_COMMIT}.tar.gz -> ghc-filesystem-${GHCFS_COMMIT}.tar.gz
	https://github.com/Cyan4973/xxHash/archive/${XXHASH_COMMIT}.tar.gz -> xxHash-${XXHASH_COMMIT}.tar.gz
	https://github.com/madler/zlib/archive/${ZLIB_COMMIT}.tar.gz -> zlib-${ZLIB_COMMIT}.tar.gz
	https://github.com/facebook/zstd/archive/${ZSTD_COMMIT}.tar.gz -> zstd-${ZSTD_COMMIT}.tar.gz
"
S="${WORKDIR}/Play--${PV}"

LICENSE="BSD-2 BSD MIT ZLIB || ( BSD GPL-2 )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+evdev libretro +vulkan"

RDEPEND="
	app-arch/bzip2
	dev-db/sqlite:3
	dev-libs/icu:=
	dev-libs/openssl:=
	dev-qt/qtbase:6[gui,opengl,widgets,X]
	media-libs/glew:0=
	media-libs/openal
	net-misc/curl
	virtual/opengl
	evdev? ( dev-libs/libevdev )
	vulkan? (
		dev-qt/qtbase:6[vulkan]
		media-libs/vulkan-loader[X]
		x11-libs/libxcb:=
	)
"
DEPEND="
	${RDEPEND}
	dev-cpp/nlohmann_json
	vulkan? ( dev-util/vulkan-headers )
"

src_unpack() {
	default

	local d
	for d in Framework CodeGen Nuanceur libchdr Dependencies; do
		rm -rf "${S}/deps/${d}" || die
	done
	mv "${WORKDIR}/Play--Framework-${FRAMEWORK_COMMIT}" "${S}/deps/Framework" || die
	mv "${WORKDIR}/Play--CodeGen-${CODEGEN_COMMIT}" "${S}/deps/CodeGen" || die
	mv "${WORKDIR}/Nuanceur-${NUANCEUR_COMMIT}" "${S}/deps/Nuanceur" || die
	mv "${WORKDIR}/libchdr-${LIBCHDR_COMMIT}" "${S}/deps/libchdr" || die
	mv "${WORKDIR}/Play-Dependencies-${DEPENDENCIES_COMMIT}" "${S}/deps/Dependencies" || die

	local dep="${S}/deps/Dependencies"
	for d in ghc_filesystem xxHash zlib zstd; do
		rm -rf "${dep}/${d}" || die
	done
	mv "${WORKDIR}/filesystem-${GHCFS_COMMIT}" "${dep}/ghc_filesystem" || die
	mv "${WORKDIR}/xxHash-${XXHASH_COMMIT}" "${dep}/xxHash" || die
	mv "${WORKDIR}/zlib-${ZLIB_COMMIT}" "${dep}/zlib" || die
	mv "${WORKDIR}/zstd-${ZSTD_COMMIT}" "${dep}/zstd" || die
}

src_prepare() {
	# Sin .git la versión se queda en "0.30": ponemos la real
	sed -i "s/set(PROJECT_Version 0.30)/set(PROJECT_Version ${PV})/" CMakeLists.txt || die

	# No enlazar libgcc/libstdc++ estáticas (eso es para el AppImage oficial)
	sed -i \
		-e '/"-static-libgcc"/d' \
		-e '/"-static-libstdc++"/d' \
		Source/ui_qt/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_PLAY=ON
		-DBUILD_PSFPLAYER=OFF
		-DBUILD_TESTS=OFF
		-DBUILD_LIBRETRO_CORE=$(usex libretro)
		-DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=$(usex !vulkan)
		-DCMAKE_DISABLE_FIND_PACKAGE_LIBEVDEV=$(usex !evdev)
		-DCMAKE_DISABLE_FIND_PACKAGE_Qt5=ON
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	if use libretro; then
		insinto /usr/$(get_libdir)/libretro
		doins "${BUILD_DIR}"/Source/ui_libretro/play_libretro.so
	fi
}

pkg_postinst() {
	xdg_pkg_postinst

	if use vulkan; then
		elog "El renderizador Vulkan de Play! solo usa XCB. En Wayland, si"
		elog "quieres Vulkan, arráncalo con: QT_QPA_PLATFORM=xcb Play"
	fi
}
