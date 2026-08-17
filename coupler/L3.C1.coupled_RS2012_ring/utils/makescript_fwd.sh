#!/bin/sh

set -eu

: "${MITGCM_DIR:?required environment variable MITGCM_DIR is not set}"
: "${MITGCM_OPT:?required environment variable MITGCM_OPT is not set}"

build_jobs=${MITGCM_BUILD_JOBS:-8}
case $build_jobs in
  ''|*[!0-9]*)
    printf 'ERROR: MITGCM_BUILD_JOBS must be a positive integer, got %s\n' "$build_jobs" >&2
    exit 1
    ;;
  0)
    printf 'ERROR: MITGCM_BUILD_JOBS must be greater than zero\n' >&2
    exit 1
    ;;
esac

test -x "$MITGCM_DIR/tools/genmake2" || {
  printf 'ERROR: MITgcm genmake2 is not executable: %s\n' "$MITGCM_DIR/tools/genmake2" >&2
  exit 1
}
test -f "$MITGCM_OPT" || {
  printf 'ERROR: MITgcm option file does not exist: %s\n' "$MITGCM_OPT" >&2
  exit 1
}
test -d ../code || {
  printf 'ERROR: MITgcm code directory does not exist: %s\n' "$(pwd -P)/../code" >&2
  exit 1
}

rm -f -- ./*.o ./*.f
if test -f Makefile; then
  make CLEAN
  rm -f -- Makefile
fi

"$MITGCM_DIR/tools/genmake2" \
  -rootdir "$MITGCM_DIR" \
  -mpi \
  -mods ../code \
  -optfile "$MITGCM_OPT"
make depend
make -j "$build_jobs"

test -x mitgcmuv || {
  printf 'ERROR: MITgcm build completed without producing mitgcmuv\n' >&2
  exit 1
}
