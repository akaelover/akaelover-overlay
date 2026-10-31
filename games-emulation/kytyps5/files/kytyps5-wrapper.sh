#!/usr/bin/env bash
# Lanzador de KytyPS5 para Gentoo.
#
# KytyPS5 es "portable": el launcher ejecuta kyty_emulator con el directorio
# de trabajo en su propia carpeta y ahí guarda _SaveData, cachés, etc. Como
# @KYTY_DIR@ no es escribible, se sincroniza una copia en el directorio del
# usuario (solo los ficheros que han cambiado) y se ejecuta desde ella.

set -euo pipefail

src=@KYTY_DIR@
dst=${KYTYPS5_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/KytyPS5}

mkdir -p "${dst}"

while IFS= read -r -d '' f; do
	f=${f#./}
	if ! cmp -s "${src}/${f}" "${dst}/${f}"; then
		mkdir -p "$(dirname "${dst}/${f}")"
		# Copia + mv: no falla con "Text file busy" si hay otra instancia.
		cp -p "${src}/${f}" "${dst}/${f}.kytyps5-new"
		mv -f "${dst}/${f}.kytyps5-new" "${dst}/${f}"
	fi
done < <(cd "${src}" && find . -type f -print0)

run_emulator() {
	# Las rutas relativas dejan de valer al cambiar de directorio.
	local args=() a expect=0
	for a in "$@"; do
		if (( expect )) && [[ -e ${a} ]]; then
			a=$(realpath -- "${a}")
		fi
		expect=0
		case ${a} in
			--game|--game-patch|--addcont-dir|--guest-exec) expect=1 ;;
		esac
		args+=("${a}")
	done
	cd "${dst}"
	exec "${dst}/kyty_emulator" "${args[@]}"
}

case ${0##*/} in
	kytyps5-emulator)
		run_emulator "$@"
		;;
	*)
		if [[ -x ${dst}/kyty_launcher ]]; then
			cd "${dst}"
			exec "${dst}/kyty_launcher" "$@"
		fi
		run_emulator "$@"
		;;
esac
