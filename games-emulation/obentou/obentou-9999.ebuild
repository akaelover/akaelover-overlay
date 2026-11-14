# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop git-r3 toolchain-funcs

DESCRIPTION="Multi-system emulator in C (GBA, GBC, NES, PCE, SMS/GG, Coleco, Spectrum...)"
HOMEPAGE="https://yughias.github.io/Obentou/ https://github.com/yughias/Obentou"
EGIT_REPO_URI="https://github.com/yughias/Obentou.git"
# Los submódulos son solo ROMs de test (enormes); no hacen falta
EGIT_SUBMODULES=()

LICENSE="GPL-2"
SLOT="0"
RESTRICT="test"

RDEPEND="
	media-libs/libsdl3
	virtual/opengl
	|| ( kde-apps/kdialog gnome-extra/zenity )
"
DEPEND="media-libs/libsdl3"
BDEPEND="
	|| ( dev-util/xxd app-editors/vim-core )
	virtual/pkgconfig
"

src_prepare() {
	default

	# Usar las cabeceras de SDL3 del sistema, no las incluidas en el repo
	rm -r ext/include/SDL3 || die

	# Upstream guarda config.ini junto al ejecutable (/usr/bin no es escribible):
	# lo movemos a ~/.local/share/obentou/
	sed -i 's|SDL_GetBasePath()|SDL_GetPrefPath("", "obentou")|' \
		src/utils/argument.c || die
	grep -q 'SDL_GetPrefPath("", "obentou")' src/utils/argument.c \
		|| die "no se pudo parchear la ruta de config.ini"
}

src_compile() {
	emake \
		CC="$(tc-getCC)" \
		CFLAGS_COMMON="-Iconverted_assets -Iinclude -Iext/include ${CFLAGS}" \
		PLATFORM_CFLAGS="$($(tc-getPKG_CONFIG) --cflags sdl3)" \
		LIBS="${LDFLAGS} $($(tc-getPKG_CONFIG) --libs sdl3) -lGL -lm" \
		obentou
}

src_install() {
	newbin obentou obentou.bin

	insinto /usr/share/${PN}
	doins base_config.ini

	# Lanzador: crea la configuración inicial del usuario si no existe
	newbin - obentou <<-EOF
		#!/bin/sh
		cfgdir="\${XDG_DATA_HOME:-\${HOME}/.local/share}/obentou"
		if [ ! -f "\${cfgdir}/config.ini" ]; then
			mkdir -p "\${cfgdir}"
			cp "${EPREFIX}/usr/share/${PN}/base_config.ini" "\${cfgdir}/config.ini"
		fi
		exec "${EPREFIX}/usr/bin/obentou.bin" "\$@"
	EOF

	make_desktop_entry obentou Obentou "" "Game;Emulator;"
	dodoc README.md
}
