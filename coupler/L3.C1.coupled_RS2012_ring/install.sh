#!/usr/bin/env bash

set -Eeuo pipefail

case_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$case_dir"

assume_yes=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--yes]

Build the L3.C1 MITgcm component library and ESMF coupler in this case copy.
The installer refuses to reuse existing build/ or code/ directories so that a
failed or stale build cannot be mistaken for a clean installation.

Options:
  --yes       accept the compiler/environment summary without prompting
  -h, --help  show this help
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local name=$1
  [[ -n ${!name:-} ]] || die "required environment variable $name is not set"
}

require_dir() {
  [[ -d $1 ]] || die "required directory does not exist: $1"
}

require_file() {
  [[ -f $1 ]] || die "required file does not exist: $1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is not available: $1"
}

on_error() {
  local line=$1
  local status=$2
  trap - ERR
  printf 'ERROR: installation failed at line %d (exit %d)\n' "$line" "$status" >&2
  exit "$status"
}

while (($# > 0)); do
  case $1 in
    --yes)
      assume_yes=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
  shift
done

for name in \
  ESMF_DIR ESMF_LIB ESMF_MOD ESMFMKFILE ESMF_OS ESMF_COMPILER \
  WRF_DIR MITGCM_DIR SKRIPS_MPI_INC SKRIPS_MPI_LIB \
  SKRIPS_NETCDF_INCLUDE SKRIPS_NETCDF_LIB; do
  require_env "$name"
done

[[ $ESMF_OS == Linux ]] || die "unsupported ESMF_OS '$ESMF_OS' (this case currently supports Linux)"

WRF_DIR=${WRF_DIR%/}/
MITGCM_DIR=${MITGCM_DIR%/}
export WRF_DIR MITGCM_DIR

require_dir "$ESMF_DIR"
require_dir "$ESMF_LIB"
require_dir "$ESMF_MOD"
require_file "$ESMFMKFILE"
require_dir "$WRF_DIR"
require_file "${WRF_DIR}configure.wrf_cpl"
require_file "${WRF_DIR}main/libwrflib.a"
require_file "${WRF_DIR}main/module_wrf_top.o"
require_file "${WRF_DIR}main/wrf_ESMFMod.o"
require_dir "$MITGCM_DIR"
require_file "$MITGCM_DIR/tools/genmake2"
require_dir "$SKRIPS_MPI_INC"
require_dir "$SKRIPS_MPI_LIB"

for command_name in ar awk grep make mpicc mpif77 sed tcsh; do
  require_command "$command_name"
done

case $ESMF_COMPILER in
  gfortran)
    opt_suffix=gfortran
    ;;
  intel|ifort)
    opt_suffix=ifort
    ;;
  pgi)
    opt_suffix=pgi
    ;;
  *)
    die "unsupported ESMF_COMPILER '$ESMF_COMPILER' (supported: gfortran, intel/ifort, pgi)"
    ;;
esac

export MITGCM_COMPILER=$ESMF_COMPILER
export MITGCM_OPT="$case_dir/utils/mitgcm_optfile.$opt_suffix"
require_file "$MITGCM_OPT"

printf 'ESMF:          %s\n' "$ESMF_DIR"
printf 'WRF 4.7.1:    %s\n' "$WRF_DIR"
printf 'MITgcm:       %s\n' "$MITGCM_DIR"
printf 'Compiler:     %s\n' "$MITGCM_COMPILER"
printf 'MITgcm opts:  %s\n' "$MITGCM_OPT"

if ! $assume_yes; then
  [[ -t 0 ]] || die "non-interactive installation requires --yes"
  read -r -p 'Continue with this configuration? [Y/n] ' reply
  case ${reply:-Y} in
    y|Y|yes|YES|Yes)
      ;;
    *)
      printf 'Installation cancelled.\n'
      exit 0
      ;;
  esac
fi

for generated_dir in build code; do
  [[ ! -e $generated_dir ]] || die "$case_dir/$generated_dir already exists; use a fresh case copy or remove it deliberately before rebuilding"
done

trap 'on_error "$LINENO" "$?"' ERR

mkdir build code
cp -a utils/. build/
cp -a mitCode/. code/
cp -a mitSettingRS/. code/

(
  cd build
  ./makescript_fwd.sh
  [[ -x mitgcmuv ]] || die "MITgcm executable was not produced"

  shopt -s nullglob
  mpi_headers=("$SKRIPS_MPI_INC"/mpif*)
  ((${#mpi_headers[@]} > 0)) || die "no mpif* headers found in $SKRIPS_MPI_INC"
  cp -- "${mpi_headers[@]}" .
  shopt -u nullglob

  ./mkmod.sh ocn
)

require_file "$case_dir/build/mmout/mitgcm_org_ocn.mod"
require_file "$case_dir/build/mmout/libmitgcm_org_ocn.a"
require_file "$case_dir/build/mmout/libmitgcmrtl.a"

(
  cd coupledCode
  ./Allmake.sh
)

[[ -x $case_dir/coupledCode/esmf_application ]] || die "coupled executable was not produced"

printf 'Installation succeeded.\n'
printf 'Coupled executable: %s\n' "$case_dir/coupledCode/esmf_application"
