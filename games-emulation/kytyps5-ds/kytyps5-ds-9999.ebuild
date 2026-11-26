# Copyright 2026 Juan Pedro
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {18..23} )
PYTHON_COMPAT=( python3_{12..15} )

inherit cmake desktop flag-o-matic git-r3 llvm-r2 python-any-r1

DESCRIPTION="KytyPS5 fork tuned for Demon's Souls (PPSA01341, 1.005/1.007), by chenxiao07"
HOMEPAGE="https://github.com/chenxiao07/KytyPS5"
EGIT_REPO_URI="https://github.com/chenxiao07/KytyPS5.git"
EGIT_BRANCH="experiment/perf-40fps-20260926"
EGIT_SUBMODULES=( '*' )

LICENSE="GPL-2 Apache-2.0 BSD MIT LGPL-2.1+ ZLIB"
SLOT="0"
KEYWORDS=""
IUSE="game-devices-udev +lto +pgo"

# Los tests necesitan GPU/Vulkan reales.
RESTRICT="test"

# SDL2 va empaquetado (estático) y carga casi todo con dlopen, pero necesita
# las cabeceras para activar cada backend (sin ellas: sin sonido ni hotplug).
COMMON_DEPEND="
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/libglvnd
	media-libs/libpulse
	media-video/pipewire:=
	sys-apps/dbus
	virtual/libudev:=
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libXcursor
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libxkbcommon
"
DEPEND="
	${COMMON_DEPEND}
	dev-libs/wayland-protocols
"
RDEPEND="
	${COMMON_DEPEND}
	media-libs/vulkan-loader
	game-devices-udev? ( games-util/game-device-udev-rules )
"
BDEPEND="
	${PYTHON_DEPS}
	app-arch/unzip
	dev-util/glslang
	dev-util/wayland-scanner
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
	')
	net-misc/wget
	virtual/pkgconfig
"

KYTY_DIR="/opt/kytyps5-ds"

# Descarga $1 en $2 usando una caché en DISTDIR (como git-r3).
_kyty_download() {
	local url=${1} dest=${2} sha256=${3}
	local store=${PORTAGE_ACTUAL_DISTDIR:-${DISTDIR}}/kytyps5-deps
	local cached=${store}/${4:-${dest##*/}}

	addwrite "${store}"
	mkdir -p "${store}" "${dest%/*}" || die

	if [[ -f ${cached} && -n ${sha256} ]] &&
		! echo "${sha256}  ${cached}" | sha256sum -c --quiet - &>/dev/null; then
		rm -f "${cached}" || die
	fi

	if [[ ! -f ${cached} ]]; then
		[[ ${EVCS_OFFLINE} ]] && die "EVCS_OFFLINE: falta ${cached}"
		einfo "Descargando ${url} ..."
		if ! wget -nv -O "${cached}.tmp" "${url}"; then
			rm -f "${cached}.tmp"
			die "Fallo al descargar ${url}"
		fi
		mv "${cached}.tmp" "${cached}" || die
	fi

	if [[ -n ${sha256} ]]; then
		echo "${sha256}  ${cached}" | sha256sum -c --quiet - ||
			die "Checksum incorrecto: ${url}"
	fi

	cp "${cached}" "${dest}" || die
}

# Clon superficial de un commit concreto (GitHub permite fetch por SHA).
_kyty_git_commit() {
	local repo=${1} commit=${2} dest=${3}

	einfo "Obteniendo ${repo} @ ${commit:0:12} ..."
	mkdir -p "${dest}" || die
	git -C "${dest}" init -q || die
	git -C "${dest}" fetch -q --depth 1 "${repo}" "${commit}" ||
		die "Fallo al obtener ${repo} ${commit}"
	git -C "${dest}" -c advice.detachedHead=false checkout -q FETCH_HEAD || die
	if [[ -f ${dest}/.gitmodules ]]; then
		git -C "${dest}" submodule -q update --init --recursive --depth 1 ||
			die "Fallo en los submódulos de ${repo}"
	fi
}

pkg_setup() {
	# Pone /usr/lib/llvm/${LLVM_SLOT}/bin primero en el PATH: clang y ld.lld
	# del mismo LLVM (ThinLTO no admite mezclar versiones).
	llvm-r2_pkg_setup
	python-any-r1_pkg_setup
}

# Lista "nombre repo commit" de cada FetchContent_Declare de 3rdparty/CMakeLists.txt.
# Upstream renombra a veces las dependencias (zarchive_source -> zarchive_reader2),
# así que los nombres se leen siempre de ahí y no se fijan en el ebuild.
_kyty_fetch_deps() {
	awk '
		/FetchContent_Declare\(/ { d=1; n=""; r=""; t="";
			split($0, a, "("); if (a[2] != "") { split(a[2], b, " "); n=b[1] }; next }
		d && n == "" && NF { n=$1 }
		d && $1 == "GIT_REPOSITORY" { r=$2 }
		d && $1 == "GIT_TAG" { t=$2 }
		d && /\)/ && !/\(/ { if (n != "" && r != "" && t != "") print n, r, t; d=0 }
	' "${S}"/3rdparty/CMakeLists.txt || die
}

src_unpack() {
	git-r3_src_unpack

	# En los ebuilds live hay red en src_unpack, pero no en src_configure:
	# traemos aquí lo que CMake descargaría, leyendo los commits fijados.
	local name repo tag
	if [[ ! ${EVCS_OFFLINE} ]]; then
		while read -r name repo tag; do
			_kyty_git_commit "${repo}" "${tag}" "${WORKDIR}/_deps/${name}-src"
		done < <(_kyty_fetch_deps)
	fi

	# FFmpeg estático precompilado (shadps4 ext-ffmpeg-core), ligado al commit
	# corto del submódulo, igual que lo calcula su CMakeLists.
	local ff_sha
	ff_sha=$(git -C "${S}"/3rdparty/ffmpeg-core rev-parse --short HEAD) || die
	_kyty_download \
		"https://github.com/shadps4-emu/ext-ffmpeg-core/releases/download/${ff_sha}/ffmpeg-linux-x64.zip" \
		"${WORKDIR}/ffmpeg.zip" "" "shadps4-ffmpeg-${ff_sha}-linux-x64.zip"
	mkdir -p "${WORKDIR}/ffmpeg-lib" || die
	unzip -oq "${WORKDIR}/ffmpeg.zip" -d "${WORKDIR}/ffmpeg-lib" || die
}

src_prepare() {
	# Con FETCHCONTENT_SOURCE_DIR_* no se ejecuta PATCH_COMMAND (ZArchive usa CRLF).
	local zar
	zar=$(_kyty_fetch_deps | awk '$2 ~ /ZArchive/ { print $1; exit }')
	[[ -n ${zar} ]] || die "No encuentro ZArchive en 3rdparty/CMakeLists.txt"
	einfo "Aplicando zarchive-reader.patch a ZArchive (${zar})"
	git -C "${WORKDIR}/_deps/${zar}-src" apply --ignore-whitespace \
		"${S}/3rdparty/patches/zarchive-reader.patch" || die

	# FFmpeg ya descargado y descomprimido: que CMake no lo intente.
	sed -i \
		-e "s|^set(FFMPEG_ZIP_PATH .*|set(FFMPEG_ZIP_PATH \"${WORKDIR}/ffmpeg.zip\")|" \
		-e "s|^set(FFMPEG_LIB_PATH .*|set(FFMPEG_LIB_PATH \"${WORKDIR}/ffmpeg-lib\")|" \
		3rdparty/ffmpeg-core/CMakeLists.txt || die

	# Sin símbolos en Release lo hace el propio Portage (splitdebug).
	sed -i -e '/\$<\$<CONFIG:Release>:-s>/d' launcher-linux/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	# Upstream solo soporta Clang; ThinLTO necesita lld del mismo LLVM.
	local -x CC=${CHOST}-clang-${LLVM_SLOT} CXX=${CHOST}-clang++-${LLVM_SLOT}
	strip-unsupported-flags
	filter-ldflags '-fuse-ld=*'
	append-ldflags -fuse-ld=lld

	# Como build-linux.sh: -O3 y ThinLTO. El código del juego se ejecuta en
	# nativo y necesita al menos x86-64-v3 (AVX2/FMA/BMI2).
	replace-flags '-O?' -O3
	is-flagq '-march=*' || append-flags -march=x86-64-v3
	if use lto; then
		append-flags -flto=thin
		append-ldflags -flto=thin
	fi

	local mycmakeargs=(
		-DBUILD_TESTING=OFF
		# El launcher Qt no; el de Linux (SDL2 + Dear ImGui) sí.
		-DKYTY_BUILD_LAUNCHER=OFF
		-DKYTY_BUILD_LINUX_LAUNCHER=ON
		-DKYTY_ENABLE_CLANG_TIDY=OFF
		-DCMAKE_C_COMPILER_LAUNCHER=
		-DCMAKE_CXX_COMPILER_LAUNCHER=
		-DFETCHCONTENT_FULLY_DISCONNECTED=ON
		-DFETCHCONTENT_BASE_DIR="${WORKDIR}/_deps"
		-DPython3_EXECUTABLE="${PYTHON}"
	)
	# Cada dependencia de FetchContent, con el nombre que use upstream ahora
	local name repo tag
	while read -r name repo tag; do
		mycmakeargs+=( -DFETCHCONTENT_SOURCE_DIR_${name^^}="${WORKDIR}/_deps/${name}-src" )
	done < <(_kyty_fetch_deps)
	# El perfil PGO que usa el paquete oficial de Linux.
	use pgo && mycmakeargs+=( -DKYTY_PGO_USE="${S}/tools/pgo/kyty-linux.profdata" )

	cmake_src_configure
}

src_compile() {
	cmake_src_compile kyty_emulator kyty_shader_precompile kyty_launcher
}

src_install() {
	# Misma estructura que el paquete oficial (KytyPS5-linux-*.zip), que es lo
	# que esperan run_ds.sh, precompile-linux.sh y el launcher.
	insinto "${KYTY_DIR}"
	doins -r LICENSE LICENSES

	exeinto "${KYTY_DIR}"
	doexe "${BUILD_DIR}"/{kyty_emulator,kyty_shader_precompile,kyty_launcher}
	doexe tools/local/run_ds.sh precompile-linux.sh tools/local/dlss-bridge/get-dlss-linux.sh

	# Fuente del puente DLSS (get-dlss-linux.sh descarga el SDK de NVIDIA y lo compila).
	insinto "${KYTY_DIR}"/dlss-bridge
	doins tools/local/dlss-bridge/{kyty_dlss_bridge.cpp,LICENSE.txt} src/local/kyty-dlss-bridge.h

	insinto "${KYTY_DIR}"/tools/local/static-precompile
	doins tools/local/static-precompile/pass-states.json
	doins tools/local/static-precompile/hints-*.hints

	sed -e "s|@KYTY_DIR@|${EPREFIX}${KYTY_DIR}|g" \
		"${FILESDIR}"/kytyps5-ds-wrapper.sh > "${T}"/kytyps5-ds || die
	dobin "${T}"/kytyps5-ds
	dosym kytyps5-ds /usr/bin/kytyps5-ds-run

	make_desktop_entry kytyps5-ds "KytyPS5 (Demon's Souls)" applications-games "Game;Emulator;"
}

pkg_postinst() {
	elog "Este fork solo está pensado para Demon's Souls (PPSA01341) 1.005 / 1.007."
	elog
	elog "Es \"portable\" (ajustes, cachés de shaders, partidas y el DLSS que se"
	elog "compila van junto al ejecutable), así que 'kytyps5-ds' copia ${KYTY_DIR}"
	elog "a \${XDG_DATA_HOME:-~/.local/share}/KytyPS5-ds y lo ejecuta desde ahí"
	elog "(cámbialo con KYTYPS5_DS_HOME)."
	elog
	elog "  kytyps5-ds                         ventana de ajustes (kyty_launcher)"
	elog "  KYTY_GAME=/ruta/al/juego kytyps5-ds-run   arranca con run_ds.sh"
	elog
	elog "DLSS: ejecuta una vez ~/.local/share/KytyPS5-ds/get-dlss-linux.sh y usa"
	elog "KYTY_UPSCALER=dlss. FSR 3 viene incluido (KYTY_UPSCALER=fsr)."
}
