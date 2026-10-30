# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOTNET_PKG_COMPAT="10.0"

inherit desktop dotnet-pkg-base git-r3

DESCRIPTION="Emulador multisistema orientado a TAS (TASVideos)"
HOMEPAGE="https://tasvideos.org/BizHawk https://github.com/TASEmulators/BizHawk"
EGIT_REPO_URI="https://github.com/TASEmulators/BizHawk.git"
# Los nucleos nativos para Linux ya vienen precompilados en Assets/dll/,
# asi que no hacen falta los submodulos (mame, ppsspp, dosbox-x... ocupan
# muchisimo y solo sirven para recompilar esos nucleos).
EGIT_SUBMODULES=()

LICENSE="MIT GPL-2+ GPL-3+ LGPL-2.1+ BSD ZLIB"
SLOT="0"

# network-sandbox: "dotnet build" restaura los paquetes NuGet de internet.
# strip: los .so de Assets/dll son binarios precompilados del proyecto.
RESTRICT="network-sandbox strip test"

RDEPEND="
	dev-lang/mono
	dev-dotnet/libgdiplus
	dev-lang/lua:5.4
	media-libs/openal
	x11-libs/libX11
	virtual/opengl
"
BDEPEND="${DOTNET_PKG_BDEPS}"

QA_PREBUILT="opt/bizhawk/*"

pkg_setup() {
	dotnet-pkg-base_setup
}

src_compile() {
	export NUGET_PACKAGES="${T}/nuget"
	local version
	version=$(grep -Po 'MainVersion = "\K[^"]+' src/BizHawk.Common/VersionInfo.cs) \
		|| die "no se encuentra la version"

	# Lo mismo que Dist/BuildRelease.sh, pero con el hash de git-r3
	# (el arbol de trabajo no tiene .git).
	"${DOTNET_PKG_EXECUTABLE}" build BizHawk.sln -c Release -m -clp:NoSummary \
		-p:Version="${version}" -p:SourceRevisionId="${EGIT_VERSION}" \
		|| die "dotnet build ha fallado"

	sh Dist/Package.sh linux-x64 || die "Package.sh ha fallado"
}

src_install() {
	insinto /opt/bizhawk
	doins -r packaged_output/.
	fperms +x /opt/bizhawk/EmuHawkMono.sh

	# BizHawk guarda config.ini, partidas y savestates junto al .exe, y
	# /opt no es escribible. El lanzador replica la instalacion en
	# ~/.local/share/bizhawk con carpetas reales y enlaces a los ficheros.
	newbin - bizhawk <<-'EOF'
		#!/bin/sh
		BH=/opt/bizhawk
		DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bizhawk"
		mkdir -p "$DATA" || exit 1
		cp -rsfT "$BH" "$DATA" || exit 1
		cd "$DATA" || exit 1
		export LD_LIBRARY_PATH="$DATA/dll:$DATA:/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
		export MONO_CRASH_NOFILE=1
		export MONO_WINFORMS_XIM_STYLE=disabled
		exec mono EmuHawk.exe "$@"
	EOF

	make_desktop_entry bizhawk BizHawk applications-games "Game;Emulator;"
}

pkg_postinst() {
	elog "Lanza BizHawk con 'bizhawk'. Configuracion, partidas y savestates"
	elog "quedan en ~/.local/share/bizhawk/."
	elog "Las rutas a ROMs y scripts Lua deben ser absolutas, p. ej.:"
	elog "  bizhawk --lua=/ruta/script.lua /ruta/juego.nes"
	elog "Mupen64Plus (N64) no funciona en Linux; usa el nucleo Ares64."
}
