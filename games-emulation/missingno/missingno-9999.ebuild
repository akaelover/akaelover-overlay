# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.88.0"

inherit cargo desktop git-r3 udev xdg

DESCRIPTION="Multi-system emulator and debugger in Rust (GB/GBC, Atari 2600, SG-1000...)"
HOMEPAGE="https://github.com/ajoneil/missingno"
EGIT_REPO_URI="https://github.com/ajoneil/missingno.git"
# El submodulo missingno-gamedb es obligatorio (build.rs empaqueta la base de
# datos de juegos); git-r3 clona todos los submodulos por defecto.

LICENSE="MIT"
# Licencias de los crates de Rust (en un ebuild live no se pueden listar)
LICENSE+=" Apache-2.0 BSD Boost-1.0 ISC MPL-2.0 Unicode-3.0 ZLIB"
SLOT="0"
IUSE="nes sms"

RDEPEND="
	media-libs/alsa-lib
	virtual/libudev:=
	media-libs/vulkan-loader
	dev-libs/wayland
	x11-libs/libxkbcommon
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libXrandr
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_configure() {
	# Nucleos SMS y NES: los propios autores los marcan como inmaduros.
	local myfeatures=(
		$(usev nes missingno/nes)
		$(usev sms missingno/sms)
	)
	cargo_src_configure
}

src_compile() {
	cargo_src_compile -p missingno -p missingno-debugger -p missingno-remote
}

src_install() {
	local bin
	for bin in missingno missingno-debugger missingno-remote; do
		dobin "$(cargo_target_dir)/${bin}"
	done

	domenu net.andyofniall.missingno.desktop
	doicon -s scalable net.andyofniall.missingno.svg
	insinto /usr/share/metainfo
	doins net.andyofniall.missingno.metainfo.xml

	# Acceso al lector de cartuchos GBxCart RW
	udev_dorules 71-gbxcart.rules

	dodoc README.md
}

pkg_postinst() {
	udev_reload
	xdg_pkg_postinst
}

pkg_postrm() {
	udev_reload
	xdg_pkg_postrm
}
