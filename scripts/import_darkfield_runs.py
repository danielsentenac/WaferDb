#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import dataclasses
import datetime as dt
import json
import math
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Iterable


SUMMARY_FILE_NAMES = ("summary_stats.txt", "summary_stat.txt")
CSV_BIN_MIN_SIZES = {
    0: 0.5,
    1: 1.0,
    2: 2.5,
    3: 5.0,
    4: 10.0,
    5: 50.0,
}


@dataclasses.dataclass(frozen=True)
class ImportedBin:
    label: str
    particle_count: int
    min_size_um: float | None = None
    max_size_um: float | None = None
    particle_density_cm2: float | None = None
    total_area_um2: float | None = None
    notes: str | None = None


@dataclasses.dataclass(frozen=True)
class ImportedSummary:
    summary_file_path: str
    resolved_directory_path: str
    bins: tuple[ImportedBin, ...]
    total_scanned_area_um2: float | None = None
    frame_count: int | None = None
    inferred_run_type: str | None = None


@dataclasses.dataclass(frozen=True)
class RemoteRun:
    summary_path: str
    data_path: str
    measured_at: str


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Import darkfield runs found on a remote host into the configured "
            "WaferDB backend."
        ),
    )
    parser.add_argument(
        "--ssh-host",
        default="olserver38",
        help="SSH host that stores darkfield results. Default: %(default)s",
    )
    parser.add_argument(
        "--remote-root",
        default="/data/prod/rd/vac/darkfield",
        help="Remote darkfield root directory. Default: %(default)s",
    )
    parser.add_argument(
        "--api-base",
        help=(
            "WaferDB API base URL. Defaults to WAFERDB_API_BASE or the value "
            "derived from config/site.env.local."
        ),
    )
    parser.add_argument(
        "--site-env",
        default="config/site.env.local",
        help="Site env file used to derive the API URL. Default: %(default)s",
    )
    parser.add_argument(
        "--wafer",
        action="append",
        dest="wafers",
        default=[],
        help="Restrict imports to a wafer name. Can be repeated.",
    )
    parser.add_argument(
        "--limit-runs",
        type=int,
        help="Import at most this many discovered runs after filtering.",
    )
    parser.add_argument(
        "--wafer-limit",
        type=int,
        default=500,
        help="Maximum wafers to pull from the API. Backend max is 500.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Discover and parse runs without POSTing them to the backend.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print per-run progress lines.",
    )
    return parser.parse_args(argv)


def parse_site_env_file(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def derive_api_base(
    *,
    explicit_api_base: str | None,
    site_env_path: pathlib.Path,
    env: dict[str, str] | None = None,
) -> str:
    merged = dict(parse_site_env_file(site_env_path))
    if env:
        merged.update(env)

    api_base = explicit_api_base or merged.get("WAFERDB_API_BASE")
    if api_base:
        api_base = api_base.rstrip("/")
        if api_base.endswith("/api"):
            return api_base
        return f"{api_base}/api"

    scheme = merged.get("WAFERDB_SCHEME", "http")
    host = merged.get("WAFERDB_HOST", "127.0.0.1")
    port = merged.get("WAFERDB_PORT", "8081")
    context_path = merged.get("WAFERDB_CONTEXT_PATH", "/WaferDb")
    if not context_path.startswith("/"):
        context_path = f"/{context_path}"
    if context_path != "/":
        context_path = context_path.rstrip("/")
    port_segment = f":{port}" if port else ""
    return f"{scheme}://{host}{port_segment}{context_path}/api"


def run_ssh_python(host: str, script: str) -> str:
    remote_command = "python3 -c '{}'".format(script.replace("'", r"'\''"))
    result = subprocess.run(
        ["ssh", host, remote_command],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(
            f"SSH command failed on {host} with exit code {result.returncode}: {stderr}"
        )
    return result.stdout


def list_remote_runs(host: str, remote_root: str) -> list[RemoteRun]:
    encoded_root = base64.b64encode(remote_root.encode("utf-8")).decode("ascii")
    script = "\n".join(
        [
            "import base64, datetime, json, pathlib",
            f'root = pathlib.Path(base64.b64decode("{encoded_root}").decode("utf-8"))',
            'names = {"summary_stats.txt": 0, "summary_stat.txt": 1}',
            "preferred = {}",
            "for path in root.rglob('*'):",
            "    if not path.is_file() or path.name not in names:",
            "        continue",
            "    parent = str(path.parent)",
            "    rank = names[path.name]",
            "    current = preferred.get(parent)",
            "    if current is None or rank < current[0]:",
            "        measured_at = datetime.datetime.fromtimestamp(path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')",
            "        preferred[parent] = (rank, {'summaryPath': str(path), 'dataPath': parent, 'measuredAt': measured_at})",
            "for parent in sorted(preferred):",
            "    print(json.dumps(preferred[parent][1], sort_keys=True))",
        ]
    )
    output = run_ssh_python(host, script)
    runs: list[RemoteRun] = []
    for line in output.splitlines():
        payload = json.loads(line)
        runs.append(
            RemoteRun(
                summary_path=payload["summaryPath"],
                data_path=payload["dataPath"],
                measured_at=payload["measuredAt"],
            )
        )
    return runs


def fetch_remote_run_payload(host: str, summary_path: str) -> dict[str, object]:
    encoded_path = base64.b64encode(summary_path.encode("utf-8")).decode("ascii")
    script = "\n".join(
        [
            "import base64, csv, datetime, json, math, pathlib",
            f'path = pathlib.Path(base64.b64decode("{encoded_path}").decode("utf-8"))',
            "areas = {}",
            "for csv_path in sorted(path.parent.glob('*_particles.csv')):",
            "    try:",
            "        with csv_path.open(newline='') as handle:",
            "            reader = csv.DictReader(handle)",
            "            for row in reader:",
            "                try:",
            "                    bin_index = int(row['bin'])",
            "                    diameter_um = float(row['diameter_um'])",
            "                    areas[bin_index] = areas.get(bin_index, 0.0) + math.pi * (diameter_um / 2.0) ** 2",
            "                except (KeyError, ValueError):",
            "                    pass",
            "    except Exception:",
            "        pass",
            "payload = {",
            "    'summaryPath': str(path),",
            "    'dataPath': str(path.parent),",
            "    'measuredAt': datetime.datetime.fromtimestamp(path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S'),",
            "    'content': base64.b64encode(path.read_bytes()).decode('ascii'),",
            "    'areasByBin': {str(key): value for key, value in sorted(areas.items())},",
            "}",
            "print(json.dumps(payload, sort_keys=True))",
        ]
    )
    output = run_ssh_python(host, script)
    return json.loads(output)


def extract_wafer_name(summary_path: str, remote_root: str) -> str:
    summary = pathlib.PurePosixPath(summary_path)
    root = pathlib.PurePosixPath(remote_root)
    try:
        parts = summary.relative_to(root).parts
    except ValueError as exc:
        raise ValueError(
            f"Summary path {summary_path} is not under remote root {remote_root}"
        ) from exc
    if len(parts) < 2:
        raise ValueError(
            f"Summary path {summary_path} does not contain a wafer directory under {remote_root}"
        )
    return parts[0]


def parse_darkfield_summary(content: str, *, summary_file_path: str) -> ImportedSummary:
    totals_section_match = re.search(
        r"=== Totals across whole scan ===\s*(.*?)\s*(?:=== Area coverage ===|\Z)",
        content,
        re.DOTALL,
    )
    if totals_section_match is None:
        raise ValueError("Missing totals section in summary_stats.txt.")

    summary_stats = parse_summary_stats(content)
    total_area_match = re.search(
        r"^Total scanned area:\s*([0-9]+(?:\.[0-9]+)?)\s*[µμ]m²",
        content,
        re.MULTILINE,
    )
    frame_count_match = re.search(r"^Frames \(seen\):\s*(\d+)", content, re.MULTILINE)

    total_scanned_area_um2 = (
        float(total_area_match.group(1)) if total_area_match is not None else None
    )
    frame_count = int(frame_count_match.group(1)) if frame_count_match else None

    bins: list[ImportedBin] = []
    for raw_line in totals_section_match.group(1).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("ALL BINS"):
            continue

        match = re.match(r"^(.+?):\s*total\s*=\s*(\d+)\s*$", line)
        if match is None:
            continue

        label_text = match.group(1).strip()
        particle_count = int(match.group(2))
        bin_label = parse_imported_bin_label(label_text)
        summary_note = summary_stats.get(normalize_bin_key(label_text))
        density = None
        if total_scanned_area_um2 and total_scanned_area_um2 > 0:
            density = particle_count * 100000000.0 / total_scanned_area_um2

        bins.append(
            ImportedBin(
                label=bin_label["label"],
                min_size_um=bin_label["min_size_um"],
                max_size_um=bin_label["max_size_um"],
                particle_count=particle_count,
                particle_density_cm2=density,
                notes=summary_note,
            )
        )

    if not bins:
        raise ValueError("No bin totals were found in summary_stats.txt.")

    return ImportedSummary(
        summary_file_path=summary_file_path,
        resolved_directory_path=str(pathlib.PurePosixPath(summary_file_path).parent),
        bins=tuple(bins),
        total_scanned_area_um2=total_scanned_area_um2,
        frame_count=frame_count,
        inferred_run_type=infer_run_type_from_path(summary_file_path),
    )


def parse_summary_stats(content: str) -> dict[str, str]:
    section_match = re.search(
        r"=== Summary ===\s*(.*?)\s*(?:=== Totals across whole scan ===|\Z)",
        content,
        re.DOTALL,
    )
    if section_match is None:
        return {}

    stats: dict[str, str] = {}
    for raw_line in section_match.group(1).splitlines():
        line = raw_line.strip()
        if not line:
            continue
        match = re.match(
            r"^(.+?):\s*avg\s*=\s*([0-9]+(?:\.[0-9]+)?),\s*std\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*$",
            line,
        )
        if match is None:
            continue
        stats[normalize_bin_key(match.group(1))] = (
            f"Imported avg/frame {match.group(2)}, std {match.group(3)}"
        )
    return stats


def parse_imported_bin_label(label_text: str) -> dict[str, object]:
    cleaned = (
        label_text.replace("–", "-")
        .replace("µ", "u")
        .replace("μ", "u")
        .replace("\xa0", " ")
    )
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    greater_match = re.match(r"^>\s*([0-9]+(?:\.[0-9]+)?)\s*u?m$", cleaned)
    if greater_match is not None:
        min_size = float(greater_match.group(1))
        return {
            "label": f">{format_number(min_size)} um",
            "min_size_um": min_size,
            "max_size_um": None,
        }

    range_match = re.match(
        r"^([0-9]+(?:\.[0-9]+)?)\s*-\s*([0-9]+(?:\.[0-9]+)?)\s*u?m$",
        cleaned,
    )
    if range_match is not None:
        min_size = float(range_match.group(1))
        max_size = float(range_match.group(2))
        return {
            "label": f"{format_number(min_size)}-{format_number(max_size)} um",
            "min_size_um": min_size,
            "max_size_um": max_size,
        }

    return {"label": cleaned, "min_size_um": None, "max_size_um": None}


def normalize_bin_key(label: str) -> str:
    normalized = label.replace("–", "-").replace("µ", "u").replace("μ", "u")
    normalized = re.sub(r"\s+", "", normalized)
    return normalized.lower()


def infer_run_type_from_path(path: str) -> str:
    upper = path.upper()
    if "/BACKGROUND" in upper:
        return "background"
    return "inspection"


def format_number(value: float) -> str:
    if value == round(value):
        return f"{int(round(value))}"
    return f"{value}"


def match_csv_bin_index(bin_summary: ImportedBin) -> int | None:
    if bin_summary.min_size_um is None:
        return None
    for index, min_size in CSV_BIN_MIN_SIZES.items():
        if abs(min_size - bin_summary.min_size_um) < 0.01:
            return index
    return None


def enrich_bins_with_particle_areas(
    summary: ImportedSummary,
    areas_by_bin_index: dict[int, float],
) -> ImportedSummary:
    if not areas_by_bin_index:
        return summary

    enriched_bins: list[ImportedBin] = []
    for bin_summary in summary.bins:
        csv_bin_index = match_csv_bin_index(bin_summary)
        if csv_bin_index is None or csv_bin_index not in areas_by_bin_index:
            enriched_bins.append(bin_summary)
            continue
        enriched_bins.append(
            dataclasses.replace(
                bin_summary,
                total_area_um2=areas_by_bin_index[csv_bin_index],
            )
        )

    return dataclasses.replace(summary, bins=tuple(enriched_bins))


def build_summary_notes(
    host: str,
    summary_file_path: str,
    *,
    total_scanned_area_um2: float | None,
    frame_count: int | None,
) -> str:
    lines = [f"Imported from {host}:{summary_file_path}"]
    if total_scanned_area_um2 is not None:
        lines.append(f"Total scanned area: {total_scanned_area_um2 / 1e8:.2f} cm2")
    if frame_count is not None:
        lines.append(f"Frames: {frame_count}")
    return "\n".join(lines)


def build_darkfield_run_form(
    summary: ImportedSummary,
    *,
    host: str,
    measured_at: str,
    run_type: str,
) -> dict[str, str]:
    values = {
        "runType": run_type,
        "measuredAt": measured_at,
        "dataPath": summary.resolved_directory_path,
        "binCount": str(len(summary.bins)),
        "summaryNotes": build_summary_notes(
            host,
            summary.summary_file_path,
            total_scanned_area_um2=summary.total_scanned_area_um2,
            frame_count=summary.frame_count,
        ),
    }

    for index, bin_summary in enumerate(summary.bins):
        prefix = f"bin{index}_"
        values[f"{prefix}particleCount"] = str(bin_summary.particle_count)
        if bin_summary.label:
            values[f"{prefix}label"] = bin_summary.label
        if bin_summary.total_area_um2 is not None:
            values[f"{prefix}totalAreaUm2"] = str(bin_summary.total_area_um2)
        if bin_summary.notes:
            values[f"{prefix}notes"] = bin_summary.notes
        if bin_summary.min_size_um is not None:
            values[f"{prefix}minSizeUm"] = str(bin_summary.min_size_um)
        if bin_summary.max_size_um is not None:
            values[f"{prefix}maxSizeUm"] = str(bin_summary.max_size_um)
        if bin_summary.particle_density_cm2 is not None:
            values[f"{prefix}particleDensityCm2"] = str(bin_summary.particle_density_cm2)
    return values


def api_request_json(
    method: str,
    api_base: str,
    path: str,
    *,
    query: dict[str, str] | None = None,
    form_fields: dict[str, str] | None = None,
) -> dict[str, object]:
    url = f"{api_base.rstrip('/')}/{path.lstrip('/')}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"

    data = None
    headers = {"Accept": "application/json"}
    if form_fields is not None:
        data = urllib.parse.urlencode(form_fields).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        message = body
        try:
            payload = json.loads(body)
            if isinstance(payload, dict) and payload.get("error"):
                message = str(payload["error"])
        except json.JSONDecodeError:
            pass
        raise RuntimeError(f"{method} {url} failed with HTTP {exc.code}: {message}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{method} {url} failed: {exc.reason}") from exc


def fetch_wafers(api_base: str, limit: int) -> list[dict[str, object]]:
    payload = api_request_json("GET", api_base, "wafers", query={"limit": str(limit)})
    items = payload.get("items")
    if not isinstance(items, list):
        raise RuntimeError("Unexpected wafers payload: missing items list.")
    return [item for item in items if isinstance(item, dict)]


def fetch_wafer_detail(api_base: str, wafer_id: int) -> dict[str, object]:
    return api_request_json("GET", api_base, f"wafers/{wafer_id}")


def post_darkfield_run(api_base: str, wafer_id: int, values: dict[str, str]) -> dict[str, object]:
    return api_request_json(
        "POST",
        api_base,
        f"wafers/{wafer_id}/darkfield-runs",
        form_fields=values,
    )


def existing_data_paths(detail_payload: dict[str, object]) -> set[str]:
    runs = detail_payload.get("darkfieldRuns")
    if not isinstance(runs, list):
        return set()
    existing: set[str] = set()
    for run in runs:
        if not isinstance(run, dict):
            continue
        data_path = run.get("dataPath")
        if isinstance(data_path, str) and data_path:
            existing.add(data_path)
    return existing


def import_runs(args: argparse.Namespace) -> int:
    api_base = derive_api_base(
        explicit_api_base=args.api_base,
        site_env_path=pathlib.Path(args.site_env),
        env=dict(os_environ()),
    )
    if args.verbose:
        print(f"Using API base: {api_base}", file=sys.stderr)

    wafers = fetch_wafers(api_base, min(args.wafer_limit, 500))
    wafers_by_name = {
        str(item["name"]).casefold(): item
        for item in wafers
        if isinstance(item.get("name"), str) and "waferId" in item
    }

    requested_wafers = {name.casefold() for name in args.wafers}
    remote_runs = list_remote_runs(args.ssh_host, args.remote_root)
    filtered_runs = []
    for remote_run in remote_runs:
        wafer_name = extract_wafer_name(remote_run.summary_path, args.remote_root)
        if requested_wafers and wafer_name.casefold() not in requested_wafers:
            continue
        filtered_runs.append(remote_run)

    if args.limit_runs is not None:
        filtered_runs = filtered_runs[: args.limit_runs]

    detail_cache: dict[int, dict[str, object]] = {}
    existing_paths_cache: dict[int, set[str]] = {}

    accepted = 0
    skipped_existing = 0
    skipped_unknown_wafer = 0
    failures = 0

    for index, remote_run in enumerate(filtered_runs, start=1):
        wafer_name = extract_wafer_name(remote_run.summary_path, args.remote_root)
        wafer = wafers_by_name.get(wafer_name.casefold())
        prefix = f"[{index}/{len(filtered_runs)}] {wafer_name} :: {remote_run.data_path}"

        if wafer is None:
            skipped_unknown_wafer += 1
            print(f"{prefix} :: skipped, wafer not found in WaferDB", file=sys.stderr)
            continue

        wafer_id = int(wafer["waferId"])
        if wafer_id not in detail_cache:
            detail_cache[wafer_id] = fetch_wafer_detail(api_base, wafer_id)
            existing_paths_cache[wafer_id] = existing_data_paths(detail_cache[wafer_id])

        if remote_run.data_path in existing_paths_cache[wafer_id]:
            skipped_existing += 1
            if args.verbose:
                print(f"{prefix} :: skipped, already imported", file=sys.stderr)
            continue

        try:
            remote_payload = fetch_remote_run_payload(args.ssh_host, remote_run.summary_path)
            content = base64.b64decode(str(remote_payload["content"])).decode("utf-8")
            areas_by_bin_index = {
                int(key): float(value)
                for key, value in dict(remote_payload.get("areasByBin", {})).items()
            }
            summary = parse_darkfield_summary(
                content,
                summary_file_path=str(remote_payload["summaryPath"]),
            )
            summary = enrich_bins_with_particle_areas(summary, areas_by_bin_index)
            run_type = summary.inferred_run_type or "inspection"
            form_values = build_darkfield_run_form(
                summary,
                host=args.ssh_host,
                measured_at=str(remote_payload["measuredAt"]),
                run_type=run_type,
            )

            if args.dry_run:
                print(
                    f"{prefix} :: dry-run :: runType={run_type} :: bins={len(summary.bins)}",
                    file=sys.stderr,
                )
            else:
                post_darkfield_run(api_base, wafer_id, form_values)
                existing_paths_cache[wafer_id].add(summary.resolved_directory_path)
                print(
                    f"{prefix} :: imported :: runType={run_type} :: bins={len(summary.bins)}",
                    file=sys.stderr,
                )
            accepted += 1
        except Exception as exc:  # noqa: BLE001
            failures += 1
            print(f"{prefix} :: failed :: {exc}", file=sys.stderr)

    if args.dry_run:
        summary_line = (
            "Discovered {discovered} runs; dry-run ready {accepted}; skipped existing {existing}; "
            "skipped unknown wafers {unknown}; failures {failures}."
        )
    else:
        summary_line = (
            "Discovered {discovered} runs; imported {accepted}; skipped existing {existing}; "
            "skipped unknown wafers {unknown}; failures {failures}."
        )
    print(
        summary_line.format(
            discovered=len(filtered_runs),
            accepted=accepted,
            existing=skipped_existing,
            unknown=skipped_unknown_wafer,
            failures=failures,
        ),
        file=sys.stderr,
    )
    return 1 if failures else 0


def os_environ() -> Iterable[tuple[str, str]]:
    for key, value in dict(__import__("os").environ).items():
        yield key, value


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    return import_runs(args)


if __name__ == "__main__":
    raise SystemExit(main())
