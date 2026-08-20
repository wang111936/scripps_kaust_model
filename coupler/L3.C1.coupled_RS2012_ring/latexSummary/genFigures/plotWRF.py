#!/usr/bin/env python3
"""Render the standard SKRIPS L3.C1 WRF diagnostic figures.

The original script was written for Python 2, Basemap, and one fixed working
directory.  This Python 3 entry point preserves its diagnostics and plotting
ranges while making input, output, time steps, and fields explicit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
import sys
import tempfile
from typing import Iterable, Sequence

import matplotlib

matplotlib.use("Agg")

import cartopy.crs as ccrs
import cartopy.feature as cfeature
from cartopy.io import shapereader
import cmocean
import matplotlib.pyplot as plt
from netCDF4 import Dataset
import numpy as np


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_INPUT = (
    SCRIPT_DIR / "../../runCase/wrfout_d01_2012-06-01_00:00:00"
).resolve()
DEFAULT_OUTPUT_DIR = SCRIPT_DIR
DEFAULT_STEPS = (0, 1, 2, 3, 10, 60)
FIELD_ORDER = (
    "LH",
    "SH",
    "GSW",
    "GLW",
    "T2",
    "SST",
    "Q2",
    "current",
    "wind",
    "precip",
    "evap",
)
MAP_EXTENT = (30.0, 50.0, 10.0, 30.0)
PARALLELS = np.arange(12.0, 28.1, 4.0)
MERIDIANS = np.arange(30.0, 50.1, 4.0)
DATA_CRS = ccrs.PlateCarree()
IMAGE_SOFTWARE = "SKRIPS plotWRF.py"


@dataclass(frozen=True)
class PlotSpec:
    variables: tuple[str, ...]
    levels: np.ndarray
    ticks: np.ndarray
    cmap: object


PLOT_SPECS = {
    "LH": PlotSpec(
        ("LH",),
        np.arange(-205, 205.01, 10),
        np.arange(-200, 201, 100),
        cmocean.cm.balance,
    ),
    "SH": PlotSpec(
        ("HFX",),
        np.arange(-20.5, 20.51, 1),
        np.arange(-20, 20.01, 10),
        cmocean.cm.balance,
    ),
    "GSW": PlotSpec(
        ("SWUPB", "SWDNB"),
        np.arange(0, 2001.01, 200),
        np.arange(0, 2001.01, 500),
        cmocean.cm.thermal,
    ),
    "GLW": PlotSpec(
        ("LWUPB", "LWDNB"),
        np.arange(-205, 205.01, 10),
        np.arange(-200, 201, 100),
        cmocean.cm.balance,
    ),
    "T2": PlotSpec(
        ("T2",),
        np.arange(20, 50.01, 1),
        np.arange(20, 50.01, 5),
        cmocean.cm.thermal,
    ),
    "SST": PlotSpec(
        ("SST",),
        np.arange(24, 32.01, 0.1),
        np.arange(24, 32.01, 1),
        cmocean.cm.thermal,
    ),
    "Q2": PlotSpec(
        ("Q2",),
        np.arange(0, 0.02001, 0.0005),
        np.arange(0, 0.02001, 0.002),
        cmocean.cm.turbid,
    ),
    "current": PlotSpec(
        ("UOCE", "VOCE"),
        np.arange(0, 2.01, 0.1),
        np.arange(0, 2.01, 0.4),
        cmocean.cm.speed,
    ),
    "wind": PlotSpec(
        ("U10", "V10"),
        np.arange(0, 20.01, 1),
        np.arange(0, 20.01, 4),
        cmocean.cm.speed,
    ),
    "precip": PlotSpec(
        ("RAINCV", "RAINNCV", "RAINSHV"),
        np.arange(0, 1.001e-10, 0.02e-10),
        np.arange(0, 1.001e-10, 0.2e-10),
        cmocean.cm.speed,
    ),
    "evap": PlotSpec(
        ("QFX",),
        np.arange(0, 1.001e-7, 0.02e-7),
        np.arange(0, 1.001e-7, 0.2e-7),
        cmocean.cm.speed,
    ),
}


class PlotWRFError(RuntimeError):
    """Expected command-line or data-contract failure."""


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help=f"WRF NetCDF output (default: {DEFAULT_INPUT})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"PNG destination (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--steps",
        type=int,
        nargs="+",
        default=list(DEFAULT_STEPS),
        metavar="N",
        help="zero-based WRF time indices",
    )
    parser.add_argument(
        "--fields",
        nargs="+",
        choices=FIELD_ORDER,
        default=list(FIELD_ORDER),
        metavar="FIELD",
        help="diagnostic fields to render",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=100,
        help="PNG resolution in dots per inch (default: 100)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="replace existing output files",
    )
    parser.add_argument(
        "--stats-json",
        type=Path,
        help="optional deterministic per-array statistics manifest",
    )
    args = parser.parse_args(argv)

    args.input = resolve_path(args.input)
    args.output_dir = resolve_path(args.output_dir)
    if args.stats_json is not None:
        args.stats_json = resolve_path(args.stats_json)

    require_unique(args.steps, "time step")
    require_unique(args.fields, "field")
    if any(step < 0 for step in args.steps):
        raise PlotWRFError("time steps must be non-negative")
    if args.dpi <= 0:
        raise PlotWRFError("--dpi must be a positive integer")
    return args


def resolve_path(path: Path) -> Path:
    expanded = path.expanduser()
    if expanded.is_absolute():
        return expanded.resolve()
    return (Path.cwd() / expanded).resolve()


def require_unique(values: Sequence[object], label: str) -> None:
    if len(values) != len(set(values)):
        raise PlotWRFError(f"duplicate {label} values are not allowed")


def output_name(field: str, step: int) -> str:
    return f"wrf_{field}_{step:04d}.png"


def paths_overlap(first: Path, second: Path) -> bool:
    return (
        first == second
        or first in second.parents
        or second in first.parents
    )


def selected_variables(fields: Iterable[str]) -> tuple[str, ...]:
    names = {"XLONG", "XLAT"}
    for field in fields:
        names.update(PLOT_SPECS[field].variables)
    return tuple(sorted(names))


def validate_dataset(
    dataset: Dataset, fields: Sequence[str], steps: Sequence[int]
) -> tuple[np.ma.MaskedArray, np.ma.MaskedArray, tuple[int, int]]:
    required = selected_variables(fields)
    missing = [name for name in required if name not in dataset.variables]
    if missing:
        raise PlotWRFError("missing WRF variables: " + ", ".join(missing))

    lon_var = dataset.variables["XLONG"]
    lat_var = dataset.variables["XLAT"]
    if lon_var.ndim != 3 or lat_var.ndim != 3:
        raise PlotWRFError("XLONG and XLAT must be three-dimensional")
    if lon_var.shape[0] < 1 or lat_var.shape[0] < 1:
        raise PlotWRFError("XLONG and XLAT contain no time records")
    spatial_shape = tuple(lon_var.shape[-2:])
    if tuple(lat_var.shape[-2:]) != spatial_shape:
        raise PlotWRFError("XLONG and XLAT spatial shapes differ")

    maximum_step = max(steps)
    for name in required:
        variable = dataset.variables[name]
        if variable.ndim != 3:
            raise PlotWRFError(f"{name} must be three-dimensional")
        if tuple(variable.shape[-2:]) != spatial_shape:
            raise PlotWRFError(
                f"{name} has spatial shape {variable.shape[-2:]}, "
                f"expected {spatial_shape}"
            )
        if name not in ("XLONG", "XLAT") and variable.shape[0] <= maximum_step:
            raise PlotWRFError(
                f"time step {maximum_step} is outside {name} "
                f"(available records: {variable.shape[0]})"
            )

    longitude = np.ma.asarray(lon_var[0, :, :])
    latitude = np.ma.asarray(lat_var[0, :, :])
    return longitude, latitude, spatial_shape


def read_field(dataset: Dataset, field: str, step: int) -> np.ma.MaskedArray:
    variables = dataset.variables
    if field == "LH":
        result = variables["LH"][step, :, :]
    elif field == "SH":
        result = variables["HFX"][step, :, :]
    elif field == "GSW":
        result = (
            -variables["SWUPB"][step, :, :]
            + variables["SWDNB"][step, :, :]
        )
    elif field == "GLW":
        result = (
            -variables["LWUPB"][step, :, :]
            + variables["LWDNB"][step, :, :]
        )
    elif field == "T2":
        result = variables["T2"][step, :, :] - 273.15
    elif field == "SST":
        result = variables["SST"][step, :, :] - 273.15
    elif field == "Q2":
        result = variables["Q2"][step, :, :]
    elif field == "current":
        u_component = variables["UOCE"][step, :, :]
        v_component = variables["VOCE"][step, :, :]
        result = (u_component**2 + v_component**2) ** 0.5
    elif field == "wind":
        u_component = variables["U10"][step, :, :]
        v_component = variables["V10"][step, :, :]
        result = (u_component**2 + v_component**2) ** 0.5
    elif field == "precip":
        result = (
            variables["RAINCV"][step, :, :]
            + variables["RAINNCV"][step, :, :]
            + variables["RAINSHV"][step, :, :]
        ) / 60.0 / 1000.0
    elif field == "evap":
        result = variables["QFX"][step, :, :] / 1000.0
    else:
        raise PlotWRFError(f"unsupported field: {field}")
    return np.ma.asarray(result)


def array_statistics(
    data: np.ma.MaskedArray, field: str, step: int
) -> dict[str, object]:
    masked = np.ma.asarray(data)
    canonical = np.asarray(np.ma.filled(masked, np.nan), dtype="<f8", order="C")
    valid = masked.compressed().astype(np.float64, copy=False)
    if valid.size:
        minimum = float(np.min(valid))
        maximum = float(np.max(valid))
        mean = float(np.mean(valid))
    else:
        minimum = maximum = mean = None
    return {
        "field": field,
        "step": step,
        "shape": list(masked.shape),
        "valid_count": int(valid.size),
        "masked_count": int(masked.size - valid.size),
        "minimum": minimum,
        "maximum": maximum,
        "mean": mean,
        "canonical_float64_sha256": hashlib.sha256(canonical.tobytes()).hexdigest(),
    }


def validate_map_data() -> None:
    targets = (
        ("110m", "physical", "coastline"),
        ("110m", "cultural", "admin_0_boundary_lines_land"),
    )
    for resolution, category, name in targets:
        path = Path(shapereader.natural_earth(resolution, category, name))
        if not path.is_file():
            raise PlotWRFError(f"Cartopy map data is unavailable: {path}")


def render_figure(
    dataset: Dataset,
    longitude: np.ma.MaskedArray,
    latitude: np.ma.MaskedArray,
    field: str,
    step: int,
    destination: Path,
    dpi: int,
) -> dict[str, object]:
    data = read_field(dataset, field, step)
    spec = PLOT_SPECS[field]
    figure, axes = plt.subplots(1, 1, subplot_kw={"projection": DATA_CRS})
    try:
        axes.set_extent(MAP_EXTENT, crs=DATA_CRS)
        axes.coastlines(resolution="110m")
        axes.add_feature(cfeature.BORDERS.with_scale("110m"))
        gridlines = axes.gridlines(
            crs=DATA_CRS,
            draw_labels=True,
            xlocs=MERIDIANS,
            ylocs=PARALLELS,
            linewidth=0,
        )
        gridlines.top_labels = False
        gridlines.right_labels = False
        gridlines.xlabel_style = {"size": 14}
        gridlines.ylabel_style = {"size": 14}

        contour = axes.contourf(
            longitude,
            latitude,
            data,
            spec.levels,
            extend="both",
            cmap=spec.cmap,
            transform=DATA_CRS,
        )
        if field == "wind":
            stride = 8
            axes.quiver(
                longitude[::stride, ::stride],
                latitude[::stride, ::stride],
                dataset.variables["U10"][step, ::stride, ::stride],
                dataset.variables["V10"][step, ::stride, ::stride],
                transform=DATA_CRS,
            )
        elif field == "current":
            stride = 2
            axes.quiver(
                longitude[::stride, ::stride],
                latitude[::stride, ::stride],
                dataset.variables["UOCE"][step, ::stride, ::stride],
                dataset.variables["VOCE"][step, ::stride, ::stride],
                scale=2,
                scale_units="inches",
                transform=DATA_CRS,
            )

        caption = f"Time Step: {step:04d}, {field}"
        axes.text(0.0, 1.01, caption, transform=axes.transAxes, fontsize=15)
        colorbar_axes = figure.add_axes([0.85, 0.15, 0.03, 0.70])
        figure.colorbar(
            contour,
            cax=colorbar_axes,
            ticks=spec.ticks,
            orientation="vertical",
        )
        figure.subplots_adjust(
            hspace=0.05,
            wspace=0.10,
            left=0.15,
            right=0.85,
            top=0.95,
            bottom=0.10,
        )
        figure.set_size_inches(6.4, 4.0)
        figure.savefig(
            destination,
            dpi=dpi,
            metadata={"Software": IMAGE_SOFTWARE},
        )
    finally:
        plt.close(figure)
    return array_statistics(data, field, step)


def check_output_contract(
    output_dir: Path,
    fields: Sequence[str],
    steps: Sequence[int],
    stats_json: Path | None,
    overwrite: bool,
) -> list[Path]:
    if output_dir.exists() and not output_dir.is_dir():
        raise PlotWRFError(f"output path is not a directory: {output_dir}")
    outputs = [output_dir / output_name(field, step) for step in steps for field in fields]
    if stats_json is not None:
        if stats_json == output_dir:
            raise PlotWRFError(
                "--stats-json must not be the same path as --output-dir: "
                f"{stats_json}"
            )
        overlapping_output = next(
            (output for output in outputs if paths_overlap(stats_json, output)),
            None,
        )
        if overlapping_output is not None:
            raise PlotWRFError(
                "--stats-json must not equal, contain, or be contained by a "
                f"planned PNG path: {stats_json} conflicts with "
                f"{overlapping_output}"
            )
    conflicts = [path for path in outputs if path.exists()]
    if stats_json is not None and stats_json.exists():
        conflicts.append(stats_json)
    if conflicts and not overwrite:
        preview = ", ".join(str(path) for path in conflicts[:3])
        suffix = " ..." if len(conflicts) > 3 else ""
        raise PlotWRFError(
            f"{len(conflicts)} output file(s) already exist: {preview}{suffix}; "
            "use --overwrite to replace them"
        )
    return outputs


def atomic_write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(payload, stream, indent=2, sort_keys=True, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def run(args: argparse.Namespace) -> int:
    if not args.input.is_file():
        raise PlotWRFError(f"WRF input does not exist: {args.input}")
    if args.stats_json is not None and args.stats_json == args.input:
        raise PlotWRFError("--stats-json must not replace the WRF input file")
    if args.stats_json is not None and args.stats_json.is_dir():
        raise PlotWRFError("--stats-json must name a file, not a directory")
    outputs = check_output_contract(
        args.output_dir,
        args.fields,
        args.steps,
        args.stats_json,
        args.overwrite,
    )
    validate_map_data()

    print(f"WRF input: {args.input}")
    print(f"Output directory: {args.output_dir}")
    print(f"Time steps: {', '.join(str(step) for step in args.steps)}")
    print(f"Fields: {', '.join(args.fields)}")
    print(f"Expected images: {len(outputs)}")

    statistics: list[dict[str, object]] = []
    with Dataset(args.input, "r", format="NETCDF4") as dataset:
        longitude, latitude, spatial_shape = validate_dataset(
            dataset, args.fields, args.steps
        )
        args.output_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=".plotWRF-", dir=args.output_dir
        ) as temporary_directory:
            staging_dir = Path(temporary_directory)
            for step in args.steps:
                print(f"Plot step: {step}")
                for field in args.fields:
                    filename = output_name(field, step)
                    print(f"  Plot {field} field -> {filename}")
                    statistics.append(
                        render_figure(
                            dataset,
                            longitude,
                            latitude,
                            field,
                            step,
                            staging_dir / filename,
                            args.dpi,
                        )
                    )
            for output in outputs:
                os.replace(staging_dir / output.name, output)

    if args.stats_json is not None:
        manifest = {
            "schema": "skrips.plotWRF.statistics.v1",
            "input": str(args.input),
            "spatial_shape": list(spatial_shape),
            "steps": list(args.steps),
            "fields": list(args.fields),
            "arrays": statistics,
        }
        atomic_write_json(args.stats_json, manifest)
        print(f"Statistics: {args.stats_json}")
    print(f"Rendered {len(outputs)} image(s).")
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    try:
        return run(parse_args(argv))
    except (OSError, PlotWRFError) as error:
        print(f"plotWRF.py: error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
