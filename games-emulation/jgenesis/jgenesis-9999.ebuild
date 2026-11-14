# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo desktop git-r3 xdg

DESCRIPTION="Multi-console emulator (Genesis/CD/32X, SMS/GG, NES, SNES, GB/GBC, GBA, PCE)"
HOMEPAGE="https://github.com/jsgroth/jgenesis"
EGIT_REPO_URI="https://github.com/jsgroth/jgenesis.git"

LICENSE="GPL-3 MIT"
# Licencias de los crates de Rust (aproximado)
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD Boost-1.0 CC0-1.0 ISC
	MPL-2.0 OFL-1.1 Unicode-3.0 ZLIB
"
SLOT="0"

RDEPEND="
	media-libs/libsdl3
	media-libs/vulkan-loader
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

QA_FLAGS_IGNORED="usr/bin/jgenesis"

src_unpack() {
	git-r3_src_unpack
	# cargo fetch necesita ejecutarse donde está el Cargo.toml
	pushd "${S}" >/dev/null || die
	cargo_live_src_unpack
	popd >/dev/null || die
}

src_compile() {
	# SDL3 del sistema en vez de descargarlo y compilarlo (feature por defecto)
	export CARGO_PROFILE_RELEASE_INCREMENTAL=false
	cargo_src_compile --package jgenesis-gui --no-default-features
}

src_install() {
	dobin "$(cargo_target_dir)/jgenesis"
	newicon -s 256 frontend/256x256.png jgenesis.png
	make_desktop_entry jgenesis jgenesis jgenesis "Game;Emulator;"
	dodoc README.md
}
