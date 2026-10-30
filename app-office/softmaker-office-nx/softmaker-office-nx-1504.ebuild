# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop wrapper xdg

DESCRIPTION="SoftMaker Office NX: TextMaker, PlanMaker y Presentations (binario)"
HOMEPAGE="https://www.softmaker.com/en/products/softmaker-office"
SRC_URI="https://www.softmaker.net/down/${P}-amd64.tgz"

S="${WORKDIR}/officenx"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip test"

BDEPEND="app-arch/xz-utils"

RDEPEND="
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/libglvnd
	net-misc/curl
	sys-apps/dbus
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXmu
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXt
	x11-misc/xdg-utils
"

QA_PREBUILT="opt/${PN}/*"

src_unpack() {
	default

	# El .tgz trae el instalador y un office*.tar.lzma con la aplicación
	local lz
	lz=$(find "${WORKDIR}" -maxdepth 2 -name '*.tar.lzma' -print -quit)
	[[ -n ${lz} ]] || die "No se encontró ningún *.tar.lzma dentro del tarball"

	mkdir -p "${S}" || die
	xz -dc "${lz}" | tar -xf - -C "${S}" || die "Fallo al extraer ${lz}"
}

src_install() {
	local dest="/opt/${PN}"

	# cp -a para conservar permisos de ejecución (doins los pierde)
	dodir "${dest}"
	cp -a "${S}"/. "${ED}${dest}"/ || die

	# Lanzadores con los mismos nombres que usa el instalador oficial
	local bin
	for bin in textmaker planmaker presentations; do
		[[ -x ${S}/${bin} ]] || die "Falta el ejecutable ${bin}"
		make_wrapper "${bin}nx" "${dest}/${bin}" "${dest}"
	done

	# Iconos (tml = TextMaker, pml = PlanMaker, prl = Presentations)
	local app size f
	for app in tml pml prl; do
		for size in 16 24 32 48 64 128 256 512 1024; do
			f="${S}/icons/${app}_${size}.png"
			[[ -f ${f} ]] && newicon -s "${size}" "${f}" "softmaker-${app}nx.png"
		done
	done

	make_desktop_entry "textmakernx %F" "TextMaker NX" "softmaker-tmlnx" \
		"Office;WordProcessor;" \
		"MimeType=application/msword;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.oasis.opendocument.text;application/rtf;text/plain;"

	make_desktop_entry "planmakernx %F" "PlanMaker NX" "softmaker-pmlnx" \
		"Office;Spreadsheet;" \
		"MimeType=application/vnd.ms-excel;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;application/vnd.oasis.opendocument.spreadsheet;text/csv;"

	make_desktop_entry "presentationsnx %F" "Presentations NX" "softmaker-prlnx" \
		"Office;Presentation;" \
		"MimeType=application/vnd.ms-powerpoint;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/vnd.oasis.opendocument.presentation;"
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "SoftMaker Office NX funciona 30 días de prueba; después necesita una clave NX."
	elog "Lanzadores: textmakernx, planmakernx, presentationsnx"
}
