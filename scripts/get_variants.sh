#!/usr/bin/env bash
set -euo pipefail
trap 'echo; exit 0' INT
shopt -s nullglob # do nothing when no globs match

# the script is located in ./scripts
# however it is called from ./justfile
# consider this for the env path
# declare env_path="./env"
# if
#     [[ -d "${env_path}" ]];
# then
#     cd "${env_path}" || exit 1
#     declare files=(*.env)
#     printf "%s\n" "${files[@]}"
# else
#     exit 1
# fi

# new solution where the path is derived relative to where the script resides
# I like the idea of removing the overheading of coupling the justfile to the script
# let the script source anything on its own based on its real path
# bash_source - contains the location of the script
# script_parent - the parent directory of the script
# full_path_relative_to_script_parent - the full path up to the parent of the script
# shellcheck disable=SC2155
declare script_parent="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck disable=SC2155
declare full_path_relative_to_script_parent="$(cd -- "${script_parent}" && pwd)"
declare env_path="${full_path_relative_to_script_parent}/../env"
cd "${env_path}" || exit 1
declare files=(*.env)
printf "%s\n" "${files[@]}"

# testing within the script of confirm that they do print as a single item here
# they're returned as one ' ' separated string when accessed from the justfile/other script
# once passed elsewhere, it seems to be less overhead to use while IFS= read -r <var>; do
# for v in "${files[@]}"; do
#     printf "v: %s\n" "${v}"
# done
