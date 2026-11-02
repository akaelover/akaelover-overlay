# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake desktop xdg git-r3

DESCRIPTION="Nintendo Wii U emulator"
HOMEPAGE="https://github.com/cemu-project/Cemu"

EGIT_REPO_URI="https://github.com/cemu-project/Cemu.git"
EGIT_BRANCH="main"
EGIT_SUBMODULES=( "*" )

LICENSE="MPL-2.0"
SLOT="0"
IUSE="+bluez +cubeb discord +sdl +vulkan +wayland"
# vcpkg descarga sus dependencias durante la compilación
RESTRICT="network-sandbox"

RDEPEND="
	dev-libs/wayland
	media-libs/libglvnd
	virtual/libusb
	x11-libs/gtk+:3
	x11-libs/libX11
	wayland? (
		dev-libs/wayland-protocols
		kde-frameworks/extra-cmake-modules
	)
	bluez? ( net-wireless/bluez )
"

DEPEND="${RDEPEND}"

BDEPEND="
	dev-build/cmake
	dev-build/ninja
	dev-util/pkgconf
"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DCMAKE_DISABLE_PRECOMPILE_HEADERS=OFF
		-DENABLE_VCPKG=ON
		-DENABLE_OPENGL=ON
		"-DENABLE_VULKAN=$(usex vulkan)"
		"-DENABLE_SDL=$(usex sdl)"
		"-DENABLE_CUBEB=$(usex cubeb)"
		"-DENABLE_DISCORD_RPC=$(usex discord)"
		"-DENABLE_WAYLAND=$(usex wayland)"
		"-DENABLE_BLUEZ=$(usex bluez)"
		-DENABLE_HIDAPI=ON
		-DENABLE_LIBUSB=ON
		-DENABLE_WXWIDGETS=ON
	)

	export VCPKG_FORCE_SYSTEM_BINARIES=1
	export VCPKG_DISABLE_METRICS=1

	export PKG_CONFIG=/usr/bin/pkg-config
	# MYCMAKEARGS a proposito: el eclass lo pone al final, asi el toolchain de
	# vcpkg (que encadena el de Gentoo) se impone. pkgcheck avisa, pero es intencionado.
	local -x MYCMAKEARGS="${MYCMAKEARGS} -DCMAKE_TOOLCHAIN_FILE=${S}/dependencies/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=${BUILD_DIR}/gentoo_toolchain.cmake -DBUILD_SHARED_LIBS=OFF -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config"
	cmake_src_configure
}

src_compile() {
	export VCPKG_FORCE_SYSTEM_BINARIES=1
	export VCPKG_DISABLE_METRICS=1
	export PKG_CONFIG=/usr/bin/pkg-config
	cmake_src_compile
}

src_install() {
	if [[ -x "${S}/bin/Cemu_relwithdebinfo" ]]; then
		newbin "${S}/bin/Cemu_relwithdebinfo" Cemu
	else
		die "No se encuentra bin/Cemu_relwithdebinfo; hay que revisar la salida de compilacion."
	fi

	if [[ -d "${S}/bin/gameProfiles/default" ]]; then
		insinto "/usr/share/${PN}/gameProfiles"
		doins -r "${S}/bin/gameProfiles/default"
	fi

	if [[ -f "${S}/src/resource/logo_icon.png" ]]; then
		newicon -s 128 "${S}/src/resource/logo_icon.png" "${PN}.png"
	fi

	if [[ -d "${S}/dist" ]]; then
		local desktop_file
		for desktop_file in "${S}"/dist/*.desktop; do
			[[ -f "${desktop_file}" ]] || continue
			domenu "${desktop_file}"
		done
	fi

	dodoc "${S}/README.md" "${S}/BUILD.md"
}
