# gentoo-local

Personal Gentoo overlay by Juan Pedro ([@akaelover](https://github.com/akaelover)): emulators
(many of them live `-9999` ebuilds), the [Crafting Apps](https://github.com/storytold) suite and
a few desktop tools.

## Adding the overlay

With `app-eselect/eselect-repository`:

```sh
eselect repository add gentoo-local git https://github.com/akaelover/gentoo-local.git
emaint sync -r gentoo-local
```

`www-client/ungoogled-chromium` uses an eclass from the
[pf4public](https://github.com/PF4Public/gentoo-overlay) overlay, so that overlay is listed in
`masters` and must be enabled too:

```sh
eselect repository enable pf4public
```

## Notes

- **Live ebuilds** (`-9999`) have no `KEYWORDS`. Accept them explicitly, for example
  `games-emulation/cemu **` in `/etc/portage/package.accept_keywords`.
- **`RESTRICT="network-sandbox"`**: a few upstreams download dependencies during the build
  (vcpkg, Maven, NuGet...). Those ebuilds need network access in `src_compile`.
- **Crafting Apps** (`*craft`): Rust workspaces with forks of egui and winit pulled in through
  `[patch.crates-io]`; `src_prepare` points those patches at the unpacked git crates. If
  `rustc` dies with `SIGILL` while building one of them, it is an LLVM bug with AVX-512
  code generation: build that package with `-C target-cpu=x86-64-v3` in `RUSTFLAGS`.

## Packages

### app-office

| Package | Version | Description |
|---|---|---|
| `deckcraft` | 0.14.1 | Presentation editor with .pptx support, written in Rust |
| `designcraft` | 0.16.0 | Desktop publishing and page layout (InDesign-style), written in Rust |
| `gridcraft` | 0.15.0 | Spreadsheet with native .xlsx support, written in Rust |
| `softmaker-office-nx` | 1504 | SoftMaker Office NX: TextMaker, PlanMaker and Presentations (binary) |
| `wordcraft` | 0.14.0 | Word processor with native .docx support, written in Rust |

### app-text

| Package | Version | Description |
|---|---|---|
| `pdfcraft` | 0.17.0 | PDF reader, organizer and editor (Acrobat-style), written in Rust |

### games-emulation

| Package | Version | Description |
|---|---|---|
| `ares` | 148 | Multi-system emulator focused on accuracy (successor to higan) |
| `azahar` | 2126.2 | Nintendo 3DS emulator (unified fork of Citra and PabloMK7's Citra) |
| `bizhawk` | 9999 | Multi-system emulator aimed at tool-assisted speedruns (TASVideos) |
| `blastem` | 0.6.3_p20261017 | Fast and accurate Sega 8-bit and 16-bit emulator |
| `cemu` | 9999 | Nintendo Wii U emulator |
| `clk` | 20260723 | Clock Signal: latency-hating emulator of 8- and 16-bit platforms |
| `eden` | 9999 | Nintendo Switch emulator forked from yuzu |
| `kytyps5-ds` | 9999 | KytyPS5 fork tuned for Demon's Souls (PPSA01341, 1.005/1.007), by chenxiao07 |
| `kytyps5` | 9999 | Experimental PlayStation 5 emulator (based on Kyty) |
| `missingno` | 9999 | Multi-system emulator and debugger in Rust (GB/GBC, Atari 2600, SG-1000...) |
| `np2kai` | 9999 | Neko Project II Kai PC-9801 emulator |
| `quasi88` | 9999 | SDL2-based emulator for the NEC PC-8801 (PC-88) |
| `shadps4` | 9999 | PlayStation 4 emulator (core, without GUI) |
| `sharpemu` | 9999 | Experimental PlayStation 5 emulator (with PS4 compatibility) written in C# |
| `townsemu` | 9999 | Emulator of the Fujitsu FM TOWNS computer (Tsugaru) |
| `vita3k` | 9999 | Experimental PlayStation Vita emulator |
| `xemu` | 9999 | Original Xbox emulator (based on QEMU) |
| `xenia-canary` | 9999 | Xbox 360 emulator (Canary fork of Xenia) |
| `xenia-edge` | 9999 | Xbox 360 emulator (Edge fork of Xenia, with a native Linux build) |

### games-util

| Package | Version | Description |
|---|---|---|
| `recomp-launcher` | 0.6.0 | Installer/launcher that builds sp00nznet's game recomps from your own copy |

### media-gfx

| Package | Version | Description |
|---|---|---|
| `cadcraft` | 0.16.0 | 2D CAD drafting with DXF and DWG support (AutoCAD-style), written in Rust |
| `figcraft` | 0.14.0 | User interface design and prototyping (Figma-style), written in Rust |
| `lightcraft` | 0.17.0 | Open-source photo editor and raw developer (Lightroom-style), written in Rust |
| `photocraft` | 0.19.0 | Clean-room image editor with PSD support (Photoshop-style), in Rust |
| `texturecraft` | 0.2.0 | PBR texture painting on 3D meshes (Substance Painter-style), written in Rust |
| `vectorcraft` | 0.20.0 | Vector illustration editor with SVG and PDF (Illustrator-style), written in Rust |

### media-sound

| Package | Version | Description |
|---|---|---|
| `soundcraft` | 0.16.0 | Audio and MIDI recording, editing and mixing (Pro Tools-style), written in Rust |

### media-video

| Package | Version | Description |
|---|---|---|
| `effectcraft` | 0.20.0 | Motion graphics and VFX compositor (After Effects-style), in Rust |
| `filmcraft` | 0.16.0 | Open-source video editor with GPU compositing, written in Rust |

### net-misc

| Package | Version | Description |
|---|---|---|
| `persepolis` | 5.2.0 | Download manager with a Qt (PySide6) GUI, video downloads via yt-dlp |
| `xdm-app` | 9.0.9 | Xtreme Download Manager: download accelerator and video downloader |

### www-client

| Package | Version | Description |
|---|---|---|
| `ungoogled-chromium` | 153.0.8010.52_p1, 154.0.8037.57_p1 | Modifications to Chromium for removing Google integration and enhancing privacy |
## Resumen en español

Overlay personal de Gentoo: emuladores (muchos en versión de git, `-9999`), la colección de
aplicaciones Craft de storytold y algunas herramientas de escritorio. Se añade con
`eselect repository` como se indica arriba, y necesita también el overlay pf4public para
`ungoogled-chromium`.

## License

The ebuilds are distributed under the terms of the GNU General Public License v2, like the
Gentoo repository. Each package keeps its own upstream license (see `LICENSE` in its ebuild).
