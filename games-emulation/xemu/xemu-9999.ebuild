# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit git-r3 python-any-r1 xdg

DESCRIPTION="Emulador de la Xbox original (basado en QEMU)"
HOMEPAGE="https://xemu.app/ https://github.com/xemu-project/xemu"
EGIT_REPO_URI="https://github.com/xemu-project/xemu.git"
# Los submodulos de git son las ROMs de QEMU (seabios, edk2, u-boot...),
# que xemu no usa. Las dependencias reales son "wraps" de meson (abajo).
EGIT_SUBMODULES=()

LICENSE="GPL-2 GPL-2+ LGPL-2.1+ BSD MIT"
# dsp56300 llega como libreria estatica precompilada por el autor de xemu.
SLOT="0"
RESTRICT="test"

RDEPEND="
	dev-libs/glib:2
	dev-libs/openssl:=
	media-libs/libepoxy
	media-libs/libsamplerate
	media-libs/libsdl3
	media-libs/vulkan-loader
	media-video/pipewire:=
	net-libs/libpcap
	net-libs/libslirp
	net-misc/curl
	virtual/libusb:1
	virtual/zlib:=
	x11-libs/gtk+:3
	x11-libs/pixman
"
DEPEND="
	${RDEPEND}
	dev-util/vulkan-headers
"
BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep 'dev-python/pyyaml[${PYTHON_USEDEP}]')
	dev-build/cmake
	net-misc/curl
	dev-build/meson
	dev-build/ninja
	dev-vcs/git
	virtual/pkgconfig
"

python_check_deps() {
	python_has_version "dev-python/pyyaml[${PYTHON_USEDEP}]"
}

src_unpack() {
	git-r3_src_unpack

	# xemu baja sus dependencias (imgui, implot, glslang, volk, SDL3 si
	# falta, etc.) como subproyectos de meson. Se descargan aqui, que en
	# los ebuilds live tiene red, y luego se configura con --disable-download.
	# Ojo: los subproyectos con "method = cmake" (volk, glslang, VMA,
	# SPIRV-Reflect...) se bajan bien pero meson los da por fallidos al no
	# tener meson.build, asi que no nos fiamos de su codigo de salida y
	# comprobamos que cada wrap ha dejado su directorio.
	pushd "${S}/subprojects" >/dev/null || die
	meson subprojects download --sourcedir "${S}"
	local w d missing=()
	for w in *.wrap; do
		d=$(sed -n 's/^directory[[:space:]]*=[[:space:]]*//p' "${w}")
		[[ -n ${d} ]] || d=${w%.wrap}
		[[ -d ${d} && -n $(ls -A "${d}") ]] || missing+=( "${w%.wrap}" )
	done
	popd >/dev/null || die
	# Algunos (crates de Rust, libblkio, libvfio-user...) son opcionales y
	# no se usan en esta build; solo avisamos. Si falta uno necesario,
	# el configure lo dira.
	[[ ${#missing[@]} -eq 0 ]] || ewarn "subproyectos sin descargar: ${missing[*]}"
	[[ -f ${S}/subprojects/keycodemapdb/README ]] || die "falta keycodemapdb"

	# dsp56300 (DSP de audio, en Rust) no es un wrap: su meson.build baja
	# con curl una libreria precompilada de las releases de GitHub durante
	# el configure, donde ya no hay red. Se baja aqui con el mismo nombre
	# y meson la usa sin descargar nada.
	local dsp="${S}/subprojects/dsp56300" dspver
	dspver=$(sed -n "s/^project('dsp56300', version: '\([^']*\)').*/\1/p" "${dsp}/meson.build")
	[[ -n ${dspver} ]] || die "no se encuentra la version de dsp56300"
	local dsptar="dsp56300-${dspver}-x86_64-unknown-linux-gnu.tar.gz"
	curl -fsSL -o "${dsp}/${dsptar}" \
		"https://github.com/mborgerson/dsp56300/releases/download/v${dspver}/${dsptar}" \
		|| die "no se ha podido bajar ${dsptar}"
}

src_prepare() {
	default
	# Sin .git en el arbol, xemu-version.sh lee estos ficheros.
	echo "${EGIT_VERSION}" > XEMU_COMMIT || die
	echo "0.0.0-git" > XEMU_VERSION || die
}

src_configure() {
	# Las mismas opciones que usa build.sh en Linux, mas las de Gentoo.
	local myconf=(
		--prefix="${EPREFIX}/usr"
		--python="${PYTHON}"
		--target-list=i386-softmmu
		--disable-download
		--disable-werror
		--disable-docs
		--extra-cflags="-DXBOX=1 -Wno-error=redundant-decls ${CFLAGS}"
		--extra-ldflags="${LDFLAGS}"
	)
	./configure "${myconf[@]}" || die "configure ha fallado"
}

src_compile() {
	emake qemu-system-i386
}

src_install() {
	newbin build/qemu-system-i386 xemu

	insinto /usr/share/applications
	doins ui/xemu.desktop
	local s
	for s in 16 24 32 48 64 128 256 512; do
		insinto /usr/share/icons/hicolor/${s}x${s}/apps
		newins ui/icons/xemu_${s}x${s}.png xemu.png
	done
	insinto /usr/share/icons/hicolor/scalable/apps
	doins ui/icons/xemu.svg
	insinto /usr/share/metainfo
	doins xemu.metainfo.xml

	dodoc README.md
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "xemu necesita ficheros de una Xbox real que no se incluyen:"
	elog "  - MCPX Boot ROM (mcpx_1.0.bin)"
	elog "  - BIOS / flash (Complex 4627, etc.)"
	elog "  - Imagen de disco duro (xemu ofrece una vacia en su web)"
	elog "Se configuran en Maquina -> Ajustes -> Sistema la primera vez."
}
