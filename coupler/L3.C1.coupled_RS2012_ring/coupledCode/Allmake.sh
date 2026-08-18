#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
cd "$script_dir"

: "${ESMFMKFILE:?required environment variable ESMFMKFILE is not set}"
: "${WRF_DIR:?required environment variable WRF_DIR is not set}"

build_jobs=${COUPLER_BUILD_JOBS:-1}
case $build_jobs in
  ''|*[!0-9]*|0)
    printf 'ERROR: COUPLER_BUILD_JOBS must be a positive integer, got %s\n' "$build_jobs" >&2
    exit 1
    ;;
esac

test -f "$ESMFMKFILE" || {
  printf 'ERROR: ESMF makefile fragment does not exist: %s\n' "$ESMFMKFILE" >&2
  exit 1
}

for artifact in \
  ../build/mmout/mitgcm_org_ocn.mod \
  ../build/mmout/libmitgcm_org_ocn.a \
  ../build/mmout/libmitgcmrtl.a \
  ../build/setrlstk.o \
  ../build/sigreg.o; do
  test -f "$artifact" || {
    printf 'ERROR: required MITgcm build artifact is missing: %s\n' "$artifact" >&2
    exit 1
  }
done

make distclean

ln -sf ../build/mmout/mitgcm_org_ocn.mod .
ln -sf ../build/mmout/libmitgcm_org_ocn.a .
ln -sf ../build/mmout/libmitgcmrtl.a .
ln -sf ../build/setrlstk.o .
ln -sf ../build/sigreg.o .

make -j "$build_jobs"

test -x esmf_application || {
  printf 'ERROR: coupled build completed without producing esmf_application\n' >&2
  exit 1
}
