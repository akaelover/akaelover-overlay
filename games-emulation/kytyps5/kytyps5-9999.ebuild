# Copyright 2026 Juan Pedro
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit cmake desktop flag-o-matic git-r3 python-any-r1 toolchain-funcs xdg

DESCRIPTION="Experimental PlayStation 5 emulator (based on Kyty)"
HOMEPAGE="https://github.com/KytyPS5/KytyPS5"
EGIT_REPO_URI="https://github.com/KytyPS5/KytyPS5.git"
EGIT_SUBMODULES=( '*' )

# GPL-2 el emulador; el resto, dependencias empaquetadas (estáticas).
LICENSE="GPL-2 Apache-2.0 BSD MIT OFL-1.1 LGPL-2.1+ ZLIB"
SLOT="0"
KEYWORDS=""
IUSE="game-devices-udev +launcher"

# Los tests necesitan GPU/Vulkan reales.
RESTRICT="test"

# SDL3 va empaquetado (estático) y carga casi todo con dlopen, pero necesita
# las cabeceras en tiempo de compilación para activar cada backend.
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
	x11-libs/libXtst
	x11-libs/libxkbcommon
	launcher? (
		>=dev-qt/qtbase-6.8:6[concurrent,dbus,gui,network,ssl,widgets]
	)
"
DEPEND="
	${COMMON_DEPEND}
	dev-libs/wayland-protocols
"
RDEPEND="
	${COMMON_DEPEND}
	media-libs/vulkan-loader
	game-devices-udev? ( games-util/game-device-udev-rules )
	launcher? ( dev-qt/qtsvg:6 )
"
BDEPEND="
	${PYTHON_DEPS}
	app-arch/unzip
	dev-util/glslang
	dev-util/wayland-scanner
	llvm-core/clang
	llvm-core/lld
	net-misc/wget
	virtual/pkgconfig
"

KYTY_DIR="/opt/kytyps5"

# Descarga $1 en $2 usando una caché en DISTDIR (como git-r3) para no
# repetir descargas en cada emerge.
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
	python-any-r1_pkg_setup
}

src_unpack() {
	git-r3_src_unpack

	# En los ebuilds live hay red en src_unpack, pero no en src_configure:
	# traemos aquí lo que CMake descargaría (FetchContent / file(DOWNLOAD)),
	# leyendo los commits fijados del propio 3rdparty/CMakeLists.txt.
	local third=${S}/3rdparty/CMakeLists.txt
	local name repo tag path sha

	if [[ ! ${EVCS_OFFLINE} ]]; then
		while read -r name repo tag; do
			_kyty_git_commit "${repo}" "${tag}" "${WORKDIR}/_deps/${name}-src"
		done < <(awk '
			/FetchContent_Declare\(/ { d=1; n=""; r=""; t="";
				split($0, a, "("); if (a[2] != "") { split(a[2], b, " "); n=b[1] }; next }
			d && n == "" && NF { n=$1 }
			d && $1 == "GIT_REPOSITORY" { r=$2 }
			d && $1 == "GIT_TAG" { t=$2 }
			d && /\)/ && !/\(/ { if (n != "" && r != "" && t != "") print n, r, t; d=0 }
		' "${third}")
	fi

	# Fuentes Noto Sans (fallback de libFont): CMake se salta la descarga si
	# el fichero ya existe con el hash esperado.
	local noto_repo noto_commit
	noto_repo=$(sed -n 's/^set(KYTY_NOTO_SANS_REPOSITORY "\(.*\)")/\1/p' "${third}")
	noto_commit=$(sed -n 's/^set(KYTY_NOTO_SANS_COMMIT \([0-9a-f]*\))/\1/p' "${third}")
	[[ -n ${noto_repo} && -n ${noto_commit} ]] || die "No se encuentra Noto Sans en ${third}"
	while read -r path sha; do
		_kyty_download "${noto_repo}/${noto_commit}/fonts/${path}" \
			"${WORKDIR}/_deps/noto-sans/${path##*/}" "${sha}" \
			"noto-${noto_commit:0:12}-${path##*/}"
	done < <(awk '/^kyty_fetch_noto_sans\(/ {
			b=$0; while (b !~ /\)/) { getline l; b=b " " l }
			gsub(/^kyty_fetch_noto_sans\(|\)$/, "", b); $0=b; print $1, $2 }' "${third}")

	# FFmpeg estático precompilado por upstream (con su ffmpeg.patch); la
	# versión va ligada al commit del submódulo ext-ffmpeg-core.
	local ff_sha
	ff_sha=$(git -C "${S}" rev-parse HEAD:3rdparty/ffmpeg-core) || die
	ff_sha=${ff_sha:0:12}
	_kyty_download \
		"https://github.com/KytyPS5/ext-ffmpeg-core/releases/download/${ff_sha}/ffmpeg-linux-x64.zip" \
		"${WORKDIR}/ffmpeg-linux-x64.zip" "" "ffmpeg-${ff_sha}-linux-x64.zip"
	mkdir -p "${WORKDIR}/ffmpeg" || die
	unzip -oq "${WORKDIR}/ffmpeg-linux-x64.zip" -d "${WORKDIR}/ffmpeg" || die
}

src_prepare() {
	# Con FETCHCONTENT_SOURCE_DIR_* no se ejecuta PATCH_COMMAND: lo aplicamos
	# aquí igual que upstream (ZArchive usa CRLF, eapply no lo traga).
	einfo "Aplicando zarchive-reader.patch a ZArchive"
	git -C "${WORKDIR}/_deps/zarchive_source-src" apply --ignore-whitespace \
		"${S}/3rdparty/patches/zarchive-reader.patch" || die

	cmake_src_prepare

	# Upstream añade -march=x86-64-v3 detrás de CFLAGS y pisaría el -march del
	# usuario (p. ej. znver5). Si ya hay uno, se respeta el del usuario.
	if is-flagq '-march=*'; then
		sed -i -e 's/ -march=x86-64-v3//' src/utils.cmake || die
	fi

	# Respeta el enlazador de LDFLAGS (mold, etc.) si se ha elegido uno.
	if is-ldflagq '-fuse-ld=*'; then
		sed -i -e '/set(KYTY_LD_OPTIONS "-fuse-ld=lld")/d' CMakeLists.txt || die
	fi

	if use launcher; then
		# No empaquetar Qt dentro de la instalación: usamos el Qt del sistema.
		sed -i \
			-e 's/if(kyty_qt_plugins_dir)/if(FALSE)/' \
			-e 's|INSTALL_RPATH "\$ORIGIN/lib"|INSTALL_RPATH ""|' \
			-e 's/ -Wl,--disable-new-dtags//' \
			-e '/# Older releases require the previous executable name/,/^\t")$/d' \
			src/launcher/CMakeLists.txt || die
	fi
}

src_configure() {
	# Upstream solo soporta Clang.
	if ! tc-is-clang; then
		local -x CC=${CHOST}-clang CXX=${CHOST}-clang++
		strip-unsupported-flags
	fi

	local mycmakeargs=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}${KYTY_DIR}"
		-DBUILD_TESTING=OFF
		-DKYTY_BUILD_LAUNCHER=$(usex launcher)
		-DKYTY_ENABLE_CLANG_TIDY=OFF
		# Sin ccache/sccache automáticos (dentro del sandbox fallan).
		-DCMAKE_C_COMPILER_LAUNCHER=
		-DCMAKE_CXX_COMPILER_LAUNCHER=
		# Todo lo que FetchContent bajaría ya está en ${WORKDIR}/_deps.
		-DFETCHCONTENT_FULLY_DISCONNECTED=ON
		-DFETCHCONTENT_BASE_DIR="${WORKDIR}/_deps"
		-DFETCHCONTENT_SOURCE_DIR_OPUS="${WORKDIR}/_deps/opus-src"
		-DFETCHCONTENT_SOURCE_DIR_OPENXR="${WORKDIR}/_deps/openxr-src"
		-DFETCHCONTENT_SOURCE_DIR_XBYAK="${WORKDIR}/_deps/xbyak-src"
		-DFETCHCONTENT_SOURCE_DIR_ZYDIS="${WORKDIR}/_deps/zydis-src"
		-DFETCHCONTENT_SOURCE_DIR_ZSTD="${WORKDIR}/_deps/zstd-src"
		-DFETCHCONTENT_SOURCE_DIR_ZARCHIVE_SOURCE="${WORKDIR}/_deps/zarchive_source-src"
		-DFFMPEG_PREBUILT_DIR="${WORKDIR}/ffmpeg"
		-DPython3_EXECUTABLE="${PYTHON}"
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	local d="${ED}${KYTY_DIR}"

	# Por si alguna dependencia empaquetada empieza a instalar cosas propias:
	# todo va enlazado estáticamente y no hace falta nada de esto.
	rm -rf "${d}"/{bin,include,lib,lib64,share} || die

	# Copia con el nombre antiguo que solo usa el auto-actualizador.
	rm -f "${d}"/launcher || die

	# El auto-actualizador no tiene sentido en una instalación de Portage
	# (y en builds "Source" ni siquiera se activa).
	rm -f "${d}"/kyty_updater || die

	sed -e "s|@KYTY_DIR@|${EPREFIX}${KYTY_DIR}|g" \
		"${FILESDIR}"/kytyps5-wrapper.sh > "${T}"/kytyps5 || die
	dobin "${T}"/kytyps5
	dosym kytyps5 /usr/bin/kytyps5-emulator

	if use launcher; then
		newicon -s scalable src/launcher/icons/kyty.svg kytyps5.svg
		make_desktop_entry kytyps5 "KytyPS5" kytyps5 "Game;Emulator;"
	fi
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "KytyPS5 es \"portable\": guarda partidas (_SaveData), cachés y demás"
	elog "junto al ejecutable. Por eso 'kytyps5' y 'kytyps5-emulator' copian"
	elog "${KYTY_DIR} a \${XDG_DATA_HOME:-~/.local/share}/KytyPS5 (solo lo que"
	elog "ha cambiado) y se ejecutan desde ahí. Se puede cambiar con KYTYPS5_HOME."
	use launcher || elog "Sin USE=launcher, 'kytyps5' lanza directamente el emulador."
}
