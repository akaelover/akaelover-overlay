#!/usr/bin/env bash
# Lanzador de KytyPS5 (fork Demon's Souls) para Gentoo.
#
# El emulador es "portable": guarda ajustes (launcher-settings.json), cachés de
# shaders, partidas y el puente DLSS junto al ejecutable. Como @KYTY_DIR@ no
# es escribible, se sincroniza una copia en el directorio del usuario (solo
# los ficheros que han cambiado; lo que genere el usuario no se toca).

set -euo pipefail

src=@KYTY_DIR@
dst=${KYTYPS5_DS_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/KytyPS5-ds}

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

case ${0##*/} in
	kytyps5-ds-run)
		# run_ds.sh hace cd a su carpeta: la ruta del juego debe ser absoluta.
		if [[ -n ${KYTY_GAME:-} && -e ${KYTY_GAME} ]]; then
			KYTY_GAME=$(realpath -- "${KYTY_GAME}")
			export KYTY_GAME
		fi
		exec "${dst}/run_ds.sh" "$@"
		;;
	*)
		cd "${dst}"
		exec "${dst}/kyty_launcher" "$@"
		;;
esac
