# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {20..23} )
PYTHON_COMPAT=( python3_{12..15} )
CMAKE_BUILD_TYPE="Release"

inherit cmake desktop flag-o-matic git-r3 llvm-r2 python-any-r1 toolchain-funcs xdg

DESCRIPTION="Xbox 360 emulator (Canary fork of Xenia)"
HOMEPAGE="https://xenia.jp/ https://github.com/xenia-canary/xenia-canary"
EGIT_REPO_URI="https://github.com/xenia-canary/xenia-canary.git"
# Fuera los submodulos que solo se usan en Windows/ARM o para lint.
# DirectXShaderCompiler es enorme y en Linux no sirve para nada.
EGIT_SUBMODULES=(
	'*'
	'-third_party/DirectXShaderCompiler'
	'-third_party/DirectX-Headers'
	'-third_party/cpplint'
	'-third_party/xbyak_aarch64'
)

LICENSE="BSD"
SLOT="0"
RESTRICT="test"

RDEPEND="
	app-arch/lz4:=
	media-libs/libsdl2[joystick,sound,video]
	media-libs/vulkan-loader
	x11-libs/gtk+:3[X]
	x11-libs/libX11
	x11-libs/libxcb:=
"
DEPEND="${RDEPEND}"
# glslangValidator y spirv-opt compilan los shaders durante la compilacion;
# upstream pide SPIRV-Tools 2026.1 o mas nuevo (por --canonicalize-ids).
BDEPEND="
	${PYTHON_DEPS}
	dev-util/glslang
	dev-util/spirv-tools
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
	')
	virtual/pkgconfig
"

pkg_setup() {
	# clang, ld.lld y llvm-ar del mismo slot: con ThinLTO, un lld mas viejo
	# que clang no puede leer el bitcode ("Not an int attribute").
	llvm-r2_pkg_setup
	python-any-r1_pkg_setup
}

src_prepare() {
	# -Werror con un clang mas nuevo que el de su CI rompe la compilacion
	# por avisos nuevos; no aporta nada fuera del desarrollo.
	sed -i '/target_compile_options(${target} PRIVATE -Werror)/d' \
		cmake/XeniaHelpers.cmake || die
	cmake_src_prepare
}

src_configure() {
	# Upstream solo soporta Clang en Linux.
	if ! tc-is-clang; then
		export CC="${CHOST}-clang" CXX="${CHOST}-clang++"
		strip-unsupported-flags
	fi

	local mycmakeargs=(
		-DXENIA_BUILD_TESTS=OFF
		-DXENIA_BUILD_MISC=OFF
		-DPython3_EXECUTABLE="${PYTHON}"
	)
	cmake_src_configure

	# version.h lo genera "xb build" (xenia-build.py), no CMake.
	cat > "${BUILD_DIR}/version.h" <<-EOF || die
		#ifndef GENERATED_VERSION_H_
		#define GENERATED_VERSION_H_
		#define XE_BUILD_BRANCH "canary_experimental"
		#define XE_BUILD_COMMIT "${EGIT_VERSION}"
		#define XE_BUILD_COMMIT_SHORT "${EGIT_VERSION:0:7}"
		#define XE_BUILD_DATE __DATE__
		#endif  // GENERATED_VERSION_H_
	EOF
}

src_install() {
	dobin "${BUILD_DIR}/bin/Linux/xenia_canary"

	domenu assets/xenia_canary.desktop
	local s
	for s in 16 32 48 64 128 256 512; do
		newicon -s ${s} assets/icon/${s}.png xenia_canary.png
	done

	dodoc README.md
}

pkg_postinst() {
	xdg_pkg_postinst
	ewarn "El soporte de Linux en Xenia Canary es experimental e incompleto:"
	ewarn "muchos juegos no arrancan o fallan. Solo funciona el backend Vulkan."
	elog "La configuracion y los datos se guardan en ~/.local/share/Xenia/."
}
