#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)

printf '%s\n' 'Building the L1.C2 ESMF application...'
"$script_dir/coupledSolver/Allmake.sh" "$@"

printf '%s\n' 'Running the L1.C2 ESMF application...'
"$script_dir/run/Allrun"
