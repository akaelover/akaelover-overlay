# Copyright 2026 akaelover
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic git-r3 toolchain-funcs udev xdg

DESCRIPTION="Emulador experimental de Nintendo Switch y Switch 2 (fork de Eglantine/Eden)"
HOMEPAGE="https://lichii.zortos.me https://github.com/zortos293/Lichii"
EGIT_REPO_URI="https://github.com/zortos293/Lichii.git"

if [[ ${PV} != 9999 ]]; then
	# Las versiones siguen las etiquetas build-N del repositorio
	EGIT_COMMIT="build-${PV}"
	KEYWORDS="~amd64"
fi

# zstd va siempre empaquetado y cpmfile.json lo fija con un SHA corto (33618c8) que
# GitHub no sirve como tarball: se descarga aquí con el SHA completo
ZSTD_COMMIT="33618c89e511637f8a6ef955b3501766d71feb53"
SRC_URI="https://github.com/facebook/zstd/archive/${ZSTD_COMMIT}.tar.gz -> zstd-${ZSTD_COMMIT}.tar.gz"

LICENSE="GPL-3+ GPL-2+ LGPL-3+ MIT BSD Boost-1.0"
SLOT="0"
IUSE="discord lto pgo udev"

# CPM descarga en la configuración las dependencias que no encuentra en el sistema
# (sirit, frozen, ReShade, Streamline, tzdb…), así que necesita red.
RESTRICT="network-sandbox test"

RDEPEND="
	app-arch/lz4:=
	app-arch/zstd:=
	dev-libs/boost:=[context]
	dev-libs/libfmt:=
	dev-libs/libusb:1
	dev-libs/openssl:=
	dev-libs/quazip[qt6(+)]
	dev-qt/qtbase:6[concurrent,dbus,gui,network,widgets]
	dev-qt/qtcharts:6
	media-libs/libsdl3[haptic(+),joystick(+),sound(+),video(+)]
	media-libs/libva
	media-libs/opus
	media-libs/vulkan-loader
	media-libs/libpulse
	media-video/ffmpeg:=
	net-libs/enet:1.3=
	virtual/libudev:=
	discord? ( dev-libs/discord-rpc )
"
DEPEND="${RDEPEND}
	dev-cpp/nlohmann_json
	dev-util/spirv-headers
	dev-util/vulkan-headers
	amd64? ( dev-libs/xbyak )
"
BDEPEND="
	dev-qt/qttools:6[linguist]
	dev-util/glslang
	dev-util/spirv-tools
	virtual/pkgconfig
	pgo? (
		llvm-core/clang
		llvm-core/lld
		llvm-core/llvm
	)
	lto? ( llvm-core/lld )
"

src_unpack() {
	git-r3_src_unpack
	default
}

src_configure() {
	# El eclass añade su propio -DCMAKE_BUILD_TYPE al final; así se respeta Release
	CMAKE_BUILD_TYPE=Release

	if use pgo; then
		# El perfil es de clang: con PGO se fuerza clang aunque el sistema use GCC
		export CC="${CHOST}-clang" CXX="${CHOST}-clang++"
		strip-unsupported-flags

		# El perfil lo genera upstream con LLVM 23; un clang más viejo no puede leerlo
		local llvmbin
		llvmbin="$(dirname "$(readlink -f "$(type -P "${CC}")")")" || die
		if [[ -x ${llvmbin}/llvm-profdata ]]; then
			"${llvmbin}/llvm-profdata" show "${S}/eglantine.profdata" >/dev/null 2>&1 ||
				die "El clang de ${llvmbin} no entiende eglantine.profdata (hace falta un LLVM más nuevo; upstream usa LLVM 23)"
		fi

		append-flags "-fprofile-use=${S}/eglantine.profdata" \
			-Wno-backend-plugin -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date
	fi

	# El LTO lo controla ENABLE_LTO (CMake pone -flto, ThinLTO con clang);
	# se quitan los -flto que vengan de make.conf para no duplicarlos
	filter-lto
	if tc-is-clang; then
		# Con clang: lld (como upstream; mold necesitaría el plugin LLVMgold para LTO)
		# y las herramientas de LLVM, porque el ar de binutils no entiende el bitcode de LTO
		append-ldflags -fuse-ld=lld
		local llvmbin
		llvmbin="$(dirname "$(readlink -f "$(type -P "${CC:-clang}")")")" || die
		export AR="${llvmbin}/llvm-ar" NM="${llvmbin}/llvm-nm" RANLIB="${llvmbin}/llvm-ranlib"
	fi

	local mycmakeargs=(
		-DBUILD_TESTING=OFF
		-DYUZU_TESTS=OFF
		-DENABLE_WERROR=OFF
		-DENABLE_QT=ON
		-DENABLE_QT_TRANSLATION=ON
		-DYUZU_USE_BUNDLED_QT=OFF
		-DYUZU_USE_BUNDLED_SDL3=OFF
		-DYUZU_USE_BUNDLED_FFMPEG=OFF
		-DYUZU_USE_BUNDLED_OPENSSL=OFF
		-DYUZU_CMD=ON
		-DYUZU_ROOM=OFF
		-DYUZU_ROOM_STANDALONE=OFF
		-DYUZU_INSTALL_UDEV_RULES=OFF
		-DENABLE_UPDATE_CHECKER=OFF
		-DUSE_CCACHE=OFF
		-DUSE_DISCORD_PRESENCE=$(usex discord)
		-DENABLE_LTO=$(usex lto)
		-DLICHII_BUILD_PLATFORM=gentoo
		-Dzstd_CUSTOM_DIR="${WORKDIR}/zstd-${ZSTD_COMMIT}"
	)
	[[ ${PV} != 9999 ]] && mycmakeargs+=( -DLICHII_BUILD_TAG="build-${PV}" )

	# Para LTO CMake usa CMAKE_<LANG>_COMPILER_AR/RANLIB y los busca con el prefijo del
	# compilador (x86_64-pc-linux-gnu-llvm-ar), que LLVM no instala: se le dan a mano
	if tc-is-clang; then
		mycmakeargs+=(
			-DCMAKE_C_COMPILER_AR="${AR}"
			-DCMAKE_CXX_COMPILER_AR="${AR}"
			-DCMAKE_C_COMPILER_RANLIB="${RANLIB}"
			-DCMAKE_CXX_COMPILER_RANLIB="${RANLIB}"
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# El ejecutable de línea de comandos sigue llamándose eden-cli y choca con Eden
	mv "${ED}"/usr/bin/{eden-cli,lichii-cli} || die

	# Con nombre propio para no chocar con las reglas que instala Eden
	if use udev; then
		newudevrules dist/72-eden-input.rules 72-lichii-input.rules
	fi
}

pkg_postinst() {
	xdg_pkg_postinst
	use udev && udev_reload
	elog "Lichii comparte las carpetas de datos y la configuración de Eden/Eglantine."
	elog "Haz copia de tus partidas antes de probar builds experimentales."
}

pkg_postrm() {
	xdg_pkg_postrm
	use udev && udev_reload
}
