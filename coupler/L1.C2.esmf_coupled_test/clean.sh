#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)

test "$#" -le 1 || {
  printf 'Usage: %s [--dry-run]\n' "$0" >&2
  printf '%s\n' 'ERROR: too many arguments.' >&2
  exit 2
}

case "${1-}" in
  '')
    ;;
  --dry-run)
    "$script_dir/run/Allclean" --dry-run
    make -C "$script_dir/coupledSolver" -n distclean
    exit 0
    ;;
  -h|--help)
    printf 'Usage: %s [--dry-run]\n' "$0"
    exit 0
    ;;
  *)
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    printf 'ERROR: unknown option: %s\n' "$1" >&2
    exit 2
    ;;
esac

"$script_dir/run/Allclean"
make -C "$script_dir/coupledSolver" distclean

printf '%s\n' 'L1.C2 generated files removed.'
