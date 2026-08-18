# Supported shell quality gate

Run the same lightweight checks used by GitHub pull requests:

```sh
./tools/ci/check-supported-shell.sh
```

The command may be launched from any working directory. It requires `shellcheck`,
`sh`, `bash`, and `tcsh` and checks the explicitly listed workflow scripts hardened
in U-002 and U-004. The manifest is kept inside the checker so a missing supported
script fails clearly instead of silently reducing coverage.

This gate performs syntax and static analysis only. It does not download model data,
compile ESMF/WRF/MITgcm, run L1.C2 or L3.C1, or validate scientific output. Those
tests remain part of the external reproducible build and validation workflow.
