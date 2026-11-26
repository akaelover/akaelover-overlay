# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 toolchain-funcs xdg

DESCRIPTION="Sega Master System / Game Gear / SG-1000 emulator, debugger and embedded MCP server"
HOMEPAGE="https://github.com/drhelius/Gearsystem"
EGIT_REPO_URI="https://github.com/drhelius/Gearsystem.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

DEPEND="
	media-libs/libsdl3[opengl]
	virtual/opengl
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

src_prepare() {
	default

	# Respetar CFLAGS/CXXFLAGS/LDFLAGS del usuario: quitar -O3 y -flto forzados
	sed -i -e 's/ -O3 -flto=auto//' \
		platforms/shared/makefiles/Makefile.common || die

	# El .desktop de Debian apunta a /usr/games
	sed -i -e 's|/usr/games/gearsystem|gearsystem|g' \
		platforms/linux/debian/gearsystem.desktop || die
}

src_compile() {
	tc-export CC CXX PKG_CONFIG

	# CC/CXX/GIT_VERSION por línea de comandos; CFLAGS/CXXFLAGS/LDFLAGS
	# vienen del entorno y el Makefile los amplía con +=
	emake -C platforms/linux \
		CC="$(tc-getCC)" \
		CXX="$(tc-getCXX)" \
		DEBUG=0 \
		GIT_VERSION="9999-${EGIT_VERSION:0:7}"
}

src_install() {
	local libdir=/usr/lib/${PN}
	local shared=platforms/shared

	# El binario busca shaders, gamecontrollerdb.txt y recursos MCP junto
	# a sí mismo (SDL_GetBasePath), así que va en /usr/lib/gearsystem
	# con un enlace en /usr/bin, igual que los paquetes oficiales
	exeinto "${libdir}"
	doexe platforms/linux/${PN}
	dosym -r "${libdir}/${PN}" /usr/bin/${PN}

	insinto "${libdir}"
	doins ${shared}/gamecontrollerdb.txt

	insinto "${libdir}/shaders"
	doins ${shared}/desktop/shaders/*.gshader \
		${shared}/desktop/shaders/*.glsl \
		${shared}/desktop/shaders/README.md

	insinto "${libdir}/mcp/resources/hardware"
	doins ${shared}/desktop/mcp/resources/hardware/*.json \
		${shared}/desktop/mcp/resources/hardware/*.md

	domenu platforms/linux/debian/${PN}.desktop

	insinto /usr/share/mime/packages
	doins platforms/linux/debian/${PN}.xml

	local size
	for size in 16 24 32 48 64 128 256 512; do
		newicon -s ${size} ${shared}/desktop/icons/${PN}-${size}.png ${PN}.png
	done

	doman platforms/linux/debian/${PN}.6
	einstalldocs
}
