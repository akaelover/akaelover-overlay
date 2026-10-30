
EAPI=8

inherit cmake git-r3

DESCRIPTION="Neko Project II Kai PC-9801 emulator"
HOMEPAGE="https://github.com/piepacker/np2kai"

EGIT_REPO_URI="https://github.com/piepacker/np2kai.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND="
	media-libs/libsdl2
	media-libs/sdl2-mixer
	media-libs/sdl2-ttf
	dev-libs/openssl
	virtual/libusb:1
"
RDEPEND="${DEPEND}"
BDEPEND="
	dev-build/cmake
	dev-build/ninja
"

src_configure() {
	local mycmakeargs=(
		-DBUILD_SDL=ON
		-DBUILD_X=OFF
		-DUSE_SDL2=ON
		-DUSE_SDL_MIXER=ON
		-DUSE_SDL_TTF=ON
		-DBUILD_I286=OFF
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install
	dodoc README.md
}

src_prepare() {
	perl -pi -e '
		s/\b(?:REG8|UINT8)(?=\s+[A-Za-z_]\w*\s*\))/UINT/ if /IOOUTCALL/;
		s/\b(?:REG8|UINT8)(?=\s+IOINPCALL)/UINT/ if /IOINPCALL/;
		s/\b(?:REG8|UINT8)\s+IOOUTCALL(\s+gpib_i[0-9a-f]+\s*\()/UINT IOINPCALL$1/g;
	' cbus/*.[ch]

	perl -pi -e '
		s/psggen_setpan\(psg,/psggen_setpan(\&g_opna[0].psg,/g;
		s/psggen_getreg\(\&g_opna\[0\],/psggen_getreg(\&g_opna[0].psg,/g;
		s/psggen_restore\(\&g_opna\[0\](?:\.opngen)?\)/psggen_restore(\&g_opna[0].psg)/g;
	' cbus/boardlol.c cbus/boardmo.c

	perl -0pi -e '
		if (!/bmsio_reset_adapter/) {
			s/static const FNIORESET resetfn\[\] = \{/#if defined(SUPPORT_BMS)\nstatic void bmsio_reset_adapter(const NP2CFG *pConfig) {\n        (void)pConfig;\n        bmsio_reset();\n}\n#endif\n\nstatic const FNIORESET resetfn[] = {/;
		}
		s/^(\s*)bmsio_reset,/$1bmsio_reset_adapter,/m;
	' cbus/cbuscore.c

	cmake_src_prepare
}
