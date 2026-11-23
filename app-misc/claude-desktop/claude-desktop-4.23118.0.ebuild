# Copyright 2026 akaelover
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature unpacker xdg

DESCRIPTION="Aplicación oficial de escritorio de Claude (Chat, Cowork y Claude Code)"
HOMEPAGE="https://claude.com/download"

POOL_URI="https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/${PN}"
SRC_URI="
	amd64? ( ${POOL_URI}/${PN}_${PV}_amd64.deb )
	arm64? ( ${POOL_URI}/${PN}_${PV}_arm64.deb )
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror strip test"

# El .deb ha venido tanto con data.tar.zst como con data.tar.xz
BDEPEND="
	app-arch/xz-utils
	app-arch/zstd
"
# Dependencias típicas de una app Electron
RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libxkbcommon
	x11-libs/libXrandr
	x11-libs/pango
	x11-misc/xdg-utils
"

DEST="/opt/${PN}"
QA_PREBUILT="${DEST#/}/*"

src_install() {
	# Árbol de la app (binario Electron, resources/app.asar, chrome-sandbox…).
	# cp -a conserva los permisos del .deb, incluido el SUID de chrome-sandbox.
	dodir /opt
	cp -a usr/lib/${PN} "${ED}${DEST}" || die

	# Lanzador propio en vez del enlace de /usr/bin del .deb
	newbin - ${PN} <<-EOF
		#!/bin/sh
		# Flags extra de Electron/Chromium: una por línea en
		# \${XDG_CONFIG_HOME:-~/.config}/${PN}-flags.conf
		FLAGS_FILE="\${XDG_CONFIG_HOME:-\${HOME}/.config}/${PN}-flags.conf"
		if [ -r "\${FLAGS_FILE}" ]; then
			set -- \$(grep -v '^[[:space:]]*#' "\${FLAGS_FILE}") "\$@"
		fi
		exec ${EPREFIX}${DEST}/${PN} "\$@"
	EOF

	# Entrada de menú (corrige rutas de /usr/lib a /opt)
	if [[ -d usr/share/applications ]]; then
		sed -i \
			-e "s:/usr/lib/${PN}/${PN}:${EPREFIX}/usr/bin/${PN}:g" \
			-e "s:/usr/lib/${PN}:${EPREFIX}${DEST}:g" \
			usr/share/applications/*.desktop || die
		domenu usr/share/applications/*.desktop
	fi

	# Iconos
	if [[ -d usr/share/icons ]]; then
		insinto /usr/share
		doins -r usr/share/icons
	fi
	if [[ -d usr/share/pixmaps ]]; then
		doicon usr/share/pixmaps/*
	fi

	# No se instala nada de etc/ (repositorio apt, perfil AppArmor…)
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Flags opcionales de Electron (una por línea) en ~/.config/${PN}-flags.conf"
	elog "p. ej. --ozone-platform-hint=auto o --enable-wayland-ime"
	elog
	optfeature "Cowork (máquina virtual local; tu usuario debe estar en el grupo kvm)" \
		"app-emulation/qemu sys-firmware/edk2-bin app-emulation/virtiofsd"
}
