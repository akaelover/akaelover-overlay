# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit meson python-single-r1 xdg

DESCRIPTION="Download manager with a Qt (PySide6) GUI, video downloads via yt-dlp"
HOMEPAGE="
	https://persepolisdm.github.io/
	https://github.com/persepolisdm/persepolis
"
SRC_URI="https://github.com/persepolisdm/persepolis/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="
	${PYTHON_DEPS}
	media-video/ffmpeg
	$(python_gen_cond_dep '
		dev-python/dasbus[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pysocks[${PYTHON_USEDEP}]
		dev-python/pyside[gui,multimedia,widgets,${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/setproctitle[${PYTHON_USEDEP}]
		dev-python/urllib3[${PYTHON_USEDEP}]
		net-misc/yt-dlp[${PYTHON_USEDEP}]
	')
"
BDEPEND="${PYTHON_DEPS}"

src_prepare() {
	# check_dependencies.py solo comprueba dependencias al instalar;
	# en Portage eso lo hace RDEPEND y además intenta ejecutar ffmpeg
	sed -i '/add_install_script/d' meson.build || die

	xdg_src_prepare
}

src_install() {
	meson_src_install

	# el lanzador lleva el python que encontró meson; forzamos el elegido
	python_fix_shebang "${ED}"/usr/bin/persepolis
	python_optimize
}
