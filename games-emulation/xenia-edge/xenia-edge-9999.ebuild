# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {20..23} )
PYTHON_COMPAT=( python3_{12..15} )
CMAKE_BUILD_TYPE="Release"

inherit cmake desktop flag-o-matic git-r3 llvm-r2 python-any-r1 toolchain-funcs xdg

DESCRIPTION="Xbox 360 emulator (Edge fork of Xenia, with a native Linux build)"
HOMEPAGE="https://github.com/has207/xenia-edge"
EGIT_REPO_URI="https://github.com/has207/xenia-edge.git"
EGIT_BRANCH="edge"
# Fuera los submodulos que solo se usan en Windows/macOS/ARM o para lint.
# mesa (spirv_to_dxil) y DirectXShaderCompiler son enormes y en Linux sobran.
EGIT_SUBMODULES=(
	'*'
	'-third_party/mesa'
	'-third_party/DirectXShaderCompiler'
	'-third_party/DirectX-Headers'
	'-third_party/MoltenVK'
	'-third_party/metal-cpp'
	'-third_party/cpplint'
	'-third_party/xbyak_aarch64'
)

LICENSE="BSD"
SLOT="0"
IUSE="+lto"
RESTRICT="test"

# SDL3 y wxWidgets van empaquetados como submodulos (asi los prueba upstream).
RDEPEND="
	app-arch/lz4:=
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/libpulse
	media-libs/vulkan-loader
	sys-apps/dbus
	virtual/libudev:=
	x11-libs/gtk+:3[X]
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXrandr
	x11-libs/libXi
	x11-libs/libXcursor
	x11-libs/libXinerama
	x11-libs/libxcb:=
	x11-libs/libxkbcommon
"
DEPEND="${RDEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	dev-vcs/git
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
	')
	virtual/pkgconfig
"

src_unpack() {
	git-r3_src_unpack

	# Lo que hace "xb setup"/"xb slang": baja el compilador Slang fijado por
	# upstream (.slang/) y los repos de datos que se incrustan en el binario
	# (parches, base de datos de juegos, compatibilidad, mapeos de mandos).
	# En ebuilds live Portage permite red en src_unpack.
	pushd "${S}" >/dev/null || die
	"${EPYTHON}" - <<-'EOF' || die "no se han podido descargar slang / data repos"
		import importlib.util as u
		s = u.spec_from_file_location("xb", "xenia-build.py")
		m = u.module_from_spec(s)
		s.loader.exec_module(m)
		m.download_slang()
		m.fetch_data_repos()
	EOF
	popd >/dev/null || die
}

pkg_setup() {
	# clang, ld.lld y llvm-ar del mismo slot: con ThinLTO, un lld mas viejo
	# que clang no puede leer el bitcode ("Not an int attribute").
	llvm-r2_pkg_setup
	python-any-r1_pkg_setup
}

src_prepare() {
	# -Werror con un clang distinto al de su CI rompe por avisos nuevos.
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

	# Enlazar siempre con el ld.lld del mismo slot que clang: el del PATH
	# puede ser de otra version y no entender el bitcode de ThinLTO.
	# Tambien fuera mold/bfd de LDFLAGS: upstream exige lld.
	filter-ldflags '-fuse-ld=*' '--ld-path=*'
	local lld="$(get_llvm_prefix)/bin/ld.lld"
	[[ -x ${lld} ]] || die "falta ${lld}: instala llvm-core/lld:${LLVM_SLOT}"
	append-ldflags "--ld-path=${lld}"

	local mycmakeargs=(
		-DXENIA_BUILD_TESTS=OFF
		-DXENIA_BUILD_MISC=OFF
		-DXENIA_ENABLE_LTO=$(usex lto)
		-DPython3_EXECUTABLE="${PYTHON}"
	)
	cmake_src_configure

	# version.h lo genera "xb build" (xenia-build.py), no CMake.
	cat > "${BUILD_DIR}/version.h" <<-EOF || die
		#ifndef GENERATED_VERSION_H_
		#define GENERATED_VERSION_H_
		#define XE_BUILD_BRANCH "edge"
		#define XE_BUILD_COMMIT "${EGIT_VERSION}"
		#define XE_BUILD_COMMIT_SHORT "${EGIT_VERSION:0:7}"
		#define XE_BUILD_DATE __DATE__
		#endif  // GENERATED_VERSION_H_
	EOF
}

src_install() {
	dobin "${BUILD_DIR}/bin/Linux/xenia_edge"

	domenu assets/xenia_edge.desktop
	local s
	for s in 16 32 48 64 128 256 512; do
		newicon -s ${s} assets/icon/${s}.png xenia_edge.png
	done

	dodoc README.md
}
