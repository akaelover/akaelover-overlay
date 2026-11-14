# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: craft-gitdeps.eclass
# @MAINTAINER:
# Juan Pedro <juanpedro@tuta.io>
# @SUPPORTED_EAPIS: 8
# @BLURB: Redirige las dependencias git de las crates de GIT_CRATES a sus copias locales
# @DESCRIPTION:
# Los proyectos Craft de storytold usan varias versiones (commits) de las mismas
# crates de git: p. ej. dos commits de craft-libs, y cada uno pide su propio
# winprint. El [patch] que genera cargo.eclass solo admite un commit por crate,
# así que el resto se queda pidiendo git y falla sin red.
#
# craft_redirect_git_deps cambia, en todos los Cargo.toml de ${WORKDIR}, cada
# dependencia "crate = { git = URL, rev = X, ... }" de una crate de GIT_CRATES
# por "crate = { path = <copia descargada>, ... }". Llamarla en src_prepare.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} no soportado" ;;
esac

if [[ -z ${_CRAFT_GITDEPS_ECLASS} ]]; then
_CRAFT_GITDEPS_ECLASS=1

# @FUNCTION: craft_redirect_git_deps
# @DESCRIPTION:
# Cambia las dependencias git de las crates de GIT_CRATES por rutas locales.
craft_redirect_git_deps() {
	[[ $(declare -p GIT_CRATES 2>/dev/null) == "declare -A"* ]] || return 0

	local -a tomls
	mapfile -d '' tomls < <(find "${WORKDIR}" -name Cargo.toml \
		-not -path "${WORKDIR}/cargo_home/*" -print0)

	local crate uri commit dir path ruri
	for crate in "${!GIT_CRATES[@]}"; do
		IFS=';' read -r uri commit dir _ <<< "${GIT_CRATES[${crate}]}"
		: "${dir:=${crate}-%commit%}"
		path="${WORKDIR}/${dir//%commit%/${commit}}"
		ruri=${uri//./\\.}
		sed -i -E "s|^(${crate}[[:space:]]*=[[:space:]]*\{[[:space:]]*)git[[:space:]]*=[[:space:]]*\"${ruri}(\.git)?/?\"[[:space:]]*,[[:space:]]*rev[[:space:]]*=[[:space:]]*\"[0-9a-f]+\"|\1path = \"${path}\"|" \
			"${tomls[@]}" || die "craft_redirect_git_deps: falló con ${crate}"
	done
}

fi
