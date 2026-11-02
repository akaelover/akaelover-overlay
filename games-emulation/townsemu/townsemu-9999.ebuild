# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="An emulator of legendary Fujitsu FM TOWNS computer (Tsugaru)"
HOMEPAGE="https://github.com/captainys/TOWNSEMU"
EGIT_REPO_URI="https://github.com/captainys/TOWNSEMU.git"

LICENSE="BSD"
SLOT="0"

RDEPEND="
	media-libs/libglvnd[X]
	media-libs/glu
	media-libs/alsa-lib
	x11-libs/libX11
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-build/cmake
	dev-vcs/git
"

src_unpack() {
	# 1. Clonar repositorio principal TOWNSEMU
	git-r3_src_unpack

	# 2. Clonar repositorio secundario public usando la caché de git-r3
	EGIT_REPO_URI="https://github.com/captainys/public.git" \
	EGIT_CHECKOUT_DIR="${S}/gui/src/public" \
	git-r3_src_unpack
}

src_prepare() {
	echo "cmake_minimum_required(VERSION 3.10)" > "${S}/CMakeLists.txt"

	if [[ -f "${S}/experiments/kanjiCode/CMakeLists.txt" ]]; then
		sed -i 's/VERSION 3.8/VERSION 3.10/g' "${S}/experiments/kanjiCode/CMakeLists.txt" || die
	fi

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=OFF
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5
	)

	# 1. Configurar CUI
	BUILD_DIR="${WORKDIR}/${P}-build_cui"
	CMAKE_USE_DIR="${S}/src"
	cmake_src_configure

	# 2. Configurar GUI
	BUILD_DIR="${WORKDIR}/${P}-build_gui"
	CMAKE_USE_DIR="${S}/gui/src"
	cmake_src_configure

	# Limpiar ';' inyectados por list(APPEND) en CMAKE_CXX_FLAGS
	find "${WORKDIR}" -name "build.ninja" -o -name "flags.make" | xargs -r sed -i 's/;-/ -/g' || die
}

src_compile() {
	# 1. Compilar CUI
	BUILD_DIR="${WORKDIR}/${P}-build_cui"
	CMAKE_USE_DIR="${S}/src"
	cmake_src_compile

	# 2. Compilar GUI (el target en CMake se llama Tsugaru_GUI)
	BUILD_DIR="${WORKDIR}/${P}-build_gui"
	CMAKE_USE_DIR="${S}/gui/src"
	cmake_src_compile Tsugaru_GUI
}

src_install() {
	# Instalar binario CUI
	BUILD_DIR="${WORKDIR}/${P}-build_cui"
	find "${BUILD_DIR}" -name "Tsugaru_CUI" -type f -executable -exec dobin {} + || die "No se encontró Tsugaru_CUI"

	# Instalar binario GUI
	BUILD_DIR="${WORKDIR}/${P}-build_gui"
	find "${BUILD_DIR}" -name "Tsugaru_GUI" -type f -executable -exec dobin {} + || die "No se encontró Tsugaru_GUI"
}
