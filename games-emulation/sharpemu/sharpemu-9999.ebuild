# Copyright 2026 Juan Pedro
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOTNET_PKG_COMPAT="10.0"

inherit desktop dotnet-pkg-base git-r3 wrapper xdg

DESCRIPTION="Experimental PlayStation 5 emulator (with PS4 backward compatibility) written in C#"
HOMEPAGE="https://sharpemu.app/ https://github.com/sharpemu/sharpemu"
EGIT_REPO_URI="https://github.com/sharpemu/sharpemu.git"

LICENSE="GPL-2+ Apache-2.0 MIT"
SLOT="0"
IUSE="+demo"

# Upstream only ships the FFmpeg runtime (and supports) linux-x64.
REQUIRED_USE="amd64"
# The test suite is not wired up here; upstream runs it in CI.
RESTRICT="test"

# Self-contained publish: the .NET runtime, SDL3 and Skia are bundled,
# so only the SDK is needed at build time.
BDEPEND="${DOTNET_PKG_BDEPS}"
RDEPEND="
	dev-libs/icu
	dev-libs/openssl
	media-libs/fontconfig
	media-libs/freetype
	media-libs/vulkan-loader
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libXrandr
"

DOTNET_RID="linux-x64"
CLI_PROJ="src/SharpEmu.CLI/SharpEmu.CLI.csproj"

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && dotnet-pkg-base_setup
}

src_unpack() {
	git-r3_src_unpack

	# Live ebuild: Portage allows network access in src_unpack, so fetch
	# everything here (NuGet packages, upstream FFmpeg runtime, demo) and
	# keep src_compile fully offline.
	cd "${S}" || die
	dotnet-pkg-base_remove-global-json

	edotnet restore "${CLI_PROJ}" \
		--runtime "${DOTNET_RID}" \
		-p:Configuration="${DOTNET_PKG_CONFIGURATION}"

	local targets="FetchFfmpegRuntime"
	use demo && targets+=";FetchSharpEmuDemo"

	edotnet msbuild "${CLI_PROJ}" -nologo \
		"-t:${targets}" \
		-p:Configuration="${DOTNET_PKG_CONFIGURATION}" \
		-p:RuntimeIdentifier="${DOTNET_RID}"
}

src_compile() {
	# Shown in the log banner of the emulator.
	export GITHUB_SHA="${EGIT_VERSION}"

	local -a args=(
		--no-restore
		--configuration "${DOTNET_PKG_CONFIGURATION}"
		--runtime "${DOTNET_RID}"
		--self-contained true
		-maxCpuCount:$(makeopts_jobs)
		-p:PublishDir="${S}/gentoo-publish/"
		-p:ContinuousIntegrationBuild=true
	)
	# An empty tag makes the build skip the bundled demo cleanly.
	use demo || args+=( -p:SharpEmuDemoTag= )

	edotnet publish "${CLI_PROJ}" "${args[@]}"
}

src_install() {
	insinto /opt/${PN}
	doins -r gentoo-publish/.
	fperms +x /opt/${PN}/SharpEmu

	# Wrapper instead of a symlink so the app always resolves its own
	# directory (plugins/, demo/) from /opt/sharpemu.
	make_wrapper ${PN} /opt/${PN}/SharpEmu

	newicon assets/images/logo_transparent.png ${PN}.png
	make_desktop_entry ${PN} "SharpEmu" ${PN} "Game;Emulator;"

	dodoc README.md
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "SharpEmu stores its settings, saves, caches and logs in"
	elog "  \${XDG_DATA_HOME:-~/.local/share}/SharpEmu"
	elog "because /opt/${PN} is not writable (set SHARPEMU_USER_DIR to change it)."
	elog
	elog "The built-in updater cannot work on a system install; update with:"
	elog "  emerge --oneshot ${CATEGORY}/${PN}"
}
