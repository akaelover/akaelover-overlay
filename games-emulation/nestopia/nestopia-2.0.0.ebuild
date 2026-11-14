# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Nestopia JG 2.0.0 enlazado estáticamente con QTea (frontend Qt6),
# igual que las builds oficiales de jgemu/jgbuilds (tag nestopia-2.0.0):
#   JG_PIN=2.0.0  QTEA_PIN=0.1.1  CORE_PIN=2.0.0

inherit cmake toolchain-funcs xdg

JG_PV="2.0.0"
QTEA_PV="0.1.1"

DESCRIPTION="High-accuracy NES/Famicom emulator (Nestopia JG + QTea frontend)"
HOMEPAGE="
	http://0ldsk00l.ca/nestopia/
	https://gitlab.com/jgemu/nestopia
	https://gitlab.com/jgemu/qtea
"
SRC_URI="
	https://gitlab.com/jgemu/nestopia/-/archive/${PV}/nestopia-${PV}.tar.gz
	https://gitlab.com/jgemu/jg/-/archive/${JG_PV}/jg-${JG_PV}.tar.gz
	https://gitlab.com/jgemu/qtea/-/archive/${QTEA_PV}/qtea-${QTEA_PV}.tar.gz
"

# El directorio de CMake es QTea; el core se compila aparte en src_compile
S="${WORKDIR}/qtea-${QTEA_PV}"
NST_S="${WORKDIR}/nestopia-${PV}"
JG_S="${WORKDIR}/jg-${JG_PV}"

LICENSE="GPL-2+ LGPL-2.1+ BSD MIT ZLIB public-domain"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-arch/libarchive:=
	dev-qt/qtbase:6[gui,opengl,widgets]
	media-libs/libepoxy
	media-libs/libsdl3
	media-libs/speexdsp
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_compile() {
	local jgprefix="${WORKDIR}/jg-prefix"

	# 1) API de Jolly Good: solo cabeceras + jg.pc, a un prefijo temporal
	emake -C "${JG_S}" PREFIX="${jgprefix}" install
	export PKG_CONFIG_PATH="${jgprefix}/lib/pkgconfig:${jgprefix}/share/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

	# 2) Core de Nestopia como archivo estático (libnestopia-jg.a + jg-static.mk)
	emake -C "${NST_S}" \
		CC="$(tc-getCC)" \
		CXX="$(tc-getCXX)" \
		AR="$(tc-getAR)" \
		ENABLE_STATIC_JG=1 \
		DISABLE_MODULE=1

	[[ -f ${NST_S}/nestopia/jg-static.mk ]] \
		|| die "no se generó jg-static.mk"

	# 3) QTea enlazado contra el core
	local mycmakeargs=(
		-DQTEA_CORE_DIR="${NST_S}/nestopia"
		-DQTEA_CORE_VERSION="${PV}"
	)
	cmake_src_configure
	cmake_src_compile
}

src_configure() {
	# Se configura dentro de src_compile, cuando el core ya existe
	:
}

src_install() {
	cmake_src_install
	dodoc "${NST_S}"/{ChangeLog,README}
}
