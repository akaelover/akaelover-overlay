# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop go-module optfeature xdg

# Commit del tag v${PV}; el programa lo muestra como versión de compilación
GIT_COMMIT="005639c34bc2fc3096219fce2bd0a5ea13f8ac5b"

# Solo el proxy oficial: algún espejo de mirror://goproxy/ devuelve la
# página HTML de golang.org en vez del .mod
GOMODULE_GOPROXY_BASEURI="https://proxy.golang.org/"

EGO_SUM=(
	"github.com/creack/pty v1.1.24"
	"github.com/creack/pty v1.1.24/go.mod"
	"github.com/ebitengine/gomobile v0.0.0-20240911145611-4856209ac325"
	"github.com/ebitengine/gomobile v0.0.0-20240911145611-4856209ac325/go.mod"
	"github.com/ebitengine/hideconsole v1.0.0"
	"github.com/ebitengine/hideconsole v1.0.0/go.mod"
	"github.com/ebitengine/purego v0.8.0"
	"github.com/ebitengine/purego v0.8.0/go.mod"
	"github.com/go-text/typesetting v0.2.0"
	"github.com/go-text/typesetting v0.2.0/go.mod"
	"github.com/go-text/typesetting-utils v0.0.0-20240317173224-1986cbe96c66"
	"github.com/go-text/typesetting-utils v0.0.0-20240317173224-1986cbe96c66/go.mod"
	"github.com/hajimehoshi/bitmapfont/v3 v3.2.0"
	"github.com/hajimehoshi/bitmapfont/v3 v3.2.0/go.mod"
	"github.com/hajimehoshi/ebiten/v2 v2.8.8"
	"github.com/hajimehoshi/ebiten/v2 v2.8.8/go.mod"
	"github.com/jezek/xgb v1.1.1"
	"github.com/jezek/xgb v1.1.1/go.mod"
	"github.com/pierrec/lz4/v4 v4.1.21"
	"github.com/pierrec/lz4/v4 v4.1.21/go.mod"
	"golang.org/x/image v0.20.0"
	"golang.org/x/image v0.20.0/go.mod"
	"golang.org/x/sync v0.8.0"
	"golang.org/x/sync v0.8.0/go.mod"
	"golang.org/x/sys v0.25.0"
	"golang.org/x/sys v0.25.0/go.mod"
	"golang.org/x/text v0.18.0"
	"golang.org/x/text v0.18.0/go.mod"
)
go-module_set_globals

DESCRIPTION="Installer/launcher that builds sp00nznet's game recomps from your own copy"
HOMEPAGE="https://github.com/sp00nznet/recomp-launcher"
SRC_URI="
	https://github.com/sp00nznet/recomp-launcher/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_SUM_SRC_URI}
"

LICENSE="MIT"
# Dependent licenses
LICENSE+=" Apache-2.0 BSD MIT OFL-1.1 Unlicense"
SLOT="0"
KEYWORDS="~amd64"
# Los mirrors de Gentoo sirven una copia mala (HTML) de algún .mod: bajar
# directamente de proxy.golang.org
RESTRICT="mirror"

# Ebitengine (GLFW incluido) se compila con cgo contra X11, OpenGL y ALSA
DEPEND="
	media-libs/alsa-lib
	media-libs/libglvnd[X]
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libXinerama
	x11-libs/libXrandr
	x11-libs/libXxf86vm
"
RDEPEND="
	${DEPEND}
	app-shells/bash
	x11-misc/xdg-user-dirs
	x11-misc/xdg-utils
"
BDEPEND="virtual/pkgconfig"

src_compile() {
	local ldflags=(
		-X main.all=true
		-X main.version=v${PV}
		-X main.commit=${GIT_COMMIT}
	)
	ego build -ldflags "${ldflags[*]}" -o ${PN} .
}

src_test() {
	ego test ./...
}

src_install() {
	dobin ${PN}
	make_desktop_entry ${PN} "Recomp Launcher" applications-games "Game;Development;"
	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "the 'Choose folder' dialog" gnome-extra/zenity kde-apps/kdialog

	elog "Cada juego se compila con el script de su propio repositorio (setup.sh),"
	elog "que se descarga y ejecuta con tu usuario. Revisa qué necesita cada uno:"
	elog "suelen pedir gcc de 32 bits (multilib), cmake, ninja, SDL2 o ffmpeg."
}
