#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH='' cd -- "$script_dir/../.." && pwd -P)

fail()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command()
{
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_files()
{
    for relative_path in "$@"
    do
        [ -f "$repo_root/$relative_path" ] || fail "required script not found: $relative_path"
    done
}

run_syntax_checks()
{
    shell_name=$1
    shift

    for relative_path in "$@"
    do
        printf 'syntax (%s): %s\n' "$shell_name" "$relative_path"
        "$shell_name" -n "$repo_root/$relative_path"
    done
}

quality_script='tools/ci/check-supported-shell.sh'

l1_install='coupler/L1.C2.esmf_coupled_test/install.sh'
l1_clean='coupler/L1.C2.esmf_coupled_test/clean.sh'
l1_make='coupler/L1.C2.esmf_coupled_test/coupledSolver/Allmake.sh'
l1_run='coupler/L1.C2.esmf_coupled_test/run/Allrun'
l1_run_clean='coupler/L1.C2.esmf_coupled_test/run/Allclean'

l3_install='coupler/L3.C1.coupled_RS2012_ring/install.sh'
l3_make='coupler/L3.C1.coupled_RS2012_ring/coupledCode/Allmake.sh'
l3_init='coupler/L3.C1.coupled_RS2012_ring/runCase.init/Allrun'
l3_run='coupler/L3.C1.coupled_RS2012_ring/runCase/Allrun'
l3_forward='coupler/L3.C1.coupled_RS2012_ring/utils/makescript_fwd.sh'
l3_mkmod='coupler/L3.C1.coupled_RS2012_ring/utils/mkmod.sh'
l3_template='coupler/L3.C1.coupled_RS2012_ring/utils/template_comp.sh'

for required_command in shellcheck sh bash tcsh
do
    require_command "$required_command"
done

require_files \
    "$quality_script" \
    "$l1_install" \
    "$l1_clean" \
    "$l1_make" \
    "$l1_run" \
    "$l1_run_clean" \
    "$l3_install" \
    "$l3_make" \
    "$l3_init" \
    "$l3_run" \
    "$l3_forward" \
    "$l3_mkmod" \
    "$l3_template"

printf '%s\n' 'Running ShellCheck on the supported sh/bash scripts...'
shellcheck \
    "$repo_root/$quality_script" \
    "$repo_root/$l1_install" \
    "$repo_root/$l1_clean" \
    "$repo_root/$l1_make" \
    "$repo_root/$l1_run" \
    "$repo_root/$l1_run_clean" \
    "$repo_root/$l3_install" \
    "$repo_root/$l3_make" \
    "$repo_root/$l3_init" \
    "$repo_root/$l3_run" \
    "$repo_root/$l3_forward"

run_syntax_checks sh \
    "$quality_script" \
    "$l1_install" \
    "$l1_clean" \
    "$l1_make" \
    "$l1_run" \
    "$l1_run_clean" \
    "$l3_make" \
    "$l3_forward"

run_syntax_checks bash \
    "$l3_install" \
    "$l3_init" \
    "$l3_run"

run_syntax_checks tcsh \
    "$l3_mkmod" \
    "$l3_template"

printf '%s\n' 'PASS: supported shell script quality checks completed.'
