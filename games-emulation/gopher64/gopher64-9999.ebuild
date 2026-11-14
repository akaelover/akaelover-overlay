# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo desktop git-r3 xdg

DESCRIPTION="Cross-platform N64 emulator with rollback netplay and RetroAchievements"
HOMEPAGE="https://github.com/gopher64/gopher64"
EGIT_REPO_URI="https://github.com/gopher64/gopher64.git"
# parallel-rdp, rcheevos y sse2neon; libadrenotools es solo para Android
EGIT_SUBMODULES=( '*' '-android-project/libadrenotools' )

LICENSE="GPL-3 GPL-2 MIT"
# Licencias de los crates de Rust (aproximado)
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD Boost-1.0 CC0-1.0 ISC
	MPL-2.0 OFL-1.1 Unicode-3.0 ZLIB
"
SLOT="0"

# SDL3 y SDL3_ttf se compilan estáticos desde los crates (upstream lo fuerza);
# estas son las librerías que SDL carga en tiempo de ejecución
RDEPEND="
	dev-libs/wayland
	gui-libs/libdecor
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/libpulse
	media-libs/vulkan-loader
	media-video/pipewire
	sys-apps/dbus
	virtual/libudev:=
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXScrnSaver
	x11-libs/libxkbcommon
"
DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
	dev-util/vulkan-headers
	media-libs/libglvnd
"
BDEPEND="
	dev-build/cmake
	dev-util/wayland-scanner
	llvm-core/clang
	virtual/pkgconfig
"

QA_FLAGS_IGNORED="usr/bin/gopher64"

src_unpack() {
	git-r3_src_unpack
	pushd "${S}" >/dev/null || die
	cargo_live_src_unpack
	popd >/dev/null || die
}

src_prepare() {
	default

	# Upstream asume clang: fuerza -flto=thin (GCC no lo entiende) y
	# -march=x86-64-v3 en el código C/C++. Usamos tus CFLAGS/CXXFLAGS.
	sed -i \
		-e '/\.flag("-flto=thin");/d' \
		-e '/_build\.flag(opt_flag);/d' \
		build.rs || die
	grep -q 'flto=thin' build.rs && die "no se pudo quitar -flto=thin de build.rs"

	# Su config de cargo fuerza target-cpu=x86-64-v3 y CC=clang/AR=llvm-ar
	rm .cargo/config.toml || die
}

src_configure() {
	# bindgen necesita libclang; cogemos el LLVM más reciente instalado
	local libclang
	libclang=$(ls -d "${BROOT}"/usr/lib/llvm/*/$(get_libdir)/libclang.so 2>/dev/null \
		| sort -V | tail -n1)
	[[ -n ${libclang} ]] || die "no se encontró libclang.so"
	export LIBCLANG_PATH="${libclang%/*}"

	cargo_src_configure
}

src_compile() {
	# El perfil release de upstream hace strip; que lo gestione Portage
	export CARGO_PROFILE_RELEASE_STRIP=false
	# Upstream pide rust-version 1.100; usamos el Rust del sistema igualmente
	cargo_src_compile --bin gopher64 --ignore-rust-version
}

src_install() {
	dobin "$(cargo_target_dir)/gopher64"

	local size
	for size in 128 256 512; do
		newicon -s ${size} data/icon/gopher64_${size}x${size}.png gopher64.png
	done
	make_desktop_entry gopher64 Gopher64 gopher64 "Game;Emulator;"
	dodoc README.md
}
