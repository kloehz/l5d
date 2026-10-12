#!/usr/bin/env python3
"""Summarize the skill's benchmark JSONL; standard library only."""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def number(record: dict, key: str, where: str) -> float | None:
    value = record.get(key)
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{where}: {key} must be a number")
    value = float(value)
    if not math.isfinite(value) or value < 0:
        raise ValueError(f"{where}: {key} must be finite and nonnegative")
    return value


def percentile(values: list[float], percent: int) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * percent / 100) - 1)]


def values(records: list[dict], key: str) -> list[float]:
    return [float(r[key]) for r in records if r.get(key) is not None]


def mean(values_: list[float]) -> float | None:
    return statistics.fmean(values_) if values_ else None


def peak(values_: list[float]) -> float | None:
    return max(values_) if values_ else None


def collect(paths: list[Path], warmup: float, duration: float) -> dict:
    groups: dict = defaultdict(lambda: {"tick": [], "sample": []})
    shared = ("elapsed_s",)
    tick_fields = ("tick_ms", "rollback_ms", "rollback_ticks")
    sample_fields = (
        "cpu_core_percent", "rss_mb", "players", "active_mobs",
        "dormant_mobs", "relevant_mobs", "tx_bytes_s", "rx_bytes_s",
        "dormant_movement_steps", "dormant_ai_steps",
        "dormant_navigation_steps",
    )
    for path in paths:
        with path.open(encoding="utf-8") as stream:
            for line_no, line in enumerate(stream, 1):
                if not line.strip():
                    continue
                where = f"{path}:{line_no}"
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"{where}: invalid JSON: {exc.msg}") from exc
                if not isinstance(record, dict):
                    raise ValueError(f"{where}: expected JSON object")
                kind = record.get("kind")
                if kind == "metadata":
                    continue
                if kind not in ("tick", "sample"):
                    raise ValueError(f"{where}: unsupported record kind {kind!r}")
                for key in ("run_id", "scenario"):
                    if not isinstance(record.get(key), str) or not record[key].strip():
                        raise ValueError(f"{where}: {key} must be a nonempty string")
                for key in shared + (tick_fields if kind == "tick" else sample_fields):
                    record[key] = number(record, key, where)
                elapsed = record["elapsed_s"]
                if elapsed is None:
                    raise ValueError(f"{where}: elapsed_s is required")
                if kind == "tick" and record["tick_ms"] is None:
                    raise ValueError(f"{where}: tick_ms is required for tick records")
                if warmup <= elapsed < warmup + duration:
                    groups[(record["run_id"], record["scenario"])][kind].append(record)
    if not groups:
        raise ValueError("No tick/sample records in the requested measurement window")
    return groups


def summarize(groups: dict, goal: float) -> list[dict]:
    rows = []
    for (run_id, scenario), group in sorted(groups.items()):
        ticks = group["tick"]
        samples = group["sample"]
        tick_times = values(ticks, "tick_ms")
        all_times = values(ticks + samples, "elapsed_s")
        p95 = percentile(tick_times, 95)
        dormants = values(samples, "dormant_mobs")
        counter_names = (
            "dormant_movement_steps", "dormant_ai_steps",
            "dormant_navigation_steps",
        )
        complete = bool(samples) and all(
            sample.get(name) is not None
            for sample in samples for name in ("dormant_mobs",) + counter_names
        )
        counters = {name: peak(values(samples, name)) for name in counter_names}
        if any(value is not None and value > 0 for value in counters.values()):
            dormancy = "FAIL_DORMANCY"
        elif complete and max(dormants, default=0) > 0:
            dormancy = "PASS_DORMANCY"
        elif complete:
            dormancy = "NOT_EXERCISED"
        else:
            dormancy = "UNKNOWN"
        rows.append({
            "run_id": run_id,
            "scenario": scenario,
            "tick_count": len(ticks),
            "sample_count": len(samples),
            "observed_span_s": max(all_times) - min(all_times),
            "tick_ms_p50": percentile(tick_times, 50),
            "tick_ms_p95": p95,
            "tick_ms_p99": percentile(tick_times, 99),
            "rollback_ms_p95": percentile(values(ticks, "rollback_ms"), 95),
            "rollback_ticks_mean": mean(values(ticks, "rollback_ticks")),
            "cpu_core_percent_mean": mean(values(samples, "cpu_core_percent")),
            "rss_mb_peak": peak(values(samples, "rss_mb")),
            "players_mean": mean(values(samples, "players")),
            "active_mobs_mean": mean(values(samples, "active_mobs")),
            "dormant_mobs_mean": mean(dormants),
            "relevant_mobs_mean": mean(values(samples, "relevant_mobs")),
            "tx_bytes_s_mean": mean(values(samples, "tx_bytes_s")),
            "rx_bytes_s_mean": mean(values(samples, "rx_bytes_s")),
            **{name + "_max": value for name, value in counters.items()},
            "dormancy_status": dormancy,
            "tick_goal_status": (
                "UNKNOWN" if p95 is None else "WITHIN_GOAL" if p95 < goal else "OVER_GOAL"
            ),
        })
    return rows


def display(value) -> str:
    if value is None:
        return "NA"
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def write_outputs(rows: list[dict], args: argparse.Namespace) -> None:
    if args.csv:
        path = Path(args.csv)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    if args.markdown:
        fields = (
            "run_id", "scenario", "tick_count", "sample_count", "observed_span_s",
            "tick_ms_p95", "tick_ms_p99", "cpu_core_percent_mean", "rss_mb_peak",
            "active_mobs_mean", "dormant_mobs_mean", "tx_bytes_s_mean",
            "dormancy_status", "tick_goal_status",
        )
        lines = [
            "# Benchmark observado", "",
            f"Ventana: {args.warmup:g} ≤ elapsed_s < {args.warmup + args.duration:g}.",
            f"Objetivo p95: < {args.tick_goal_ms:g} ms. Percentiles nearest-rank.",
            "CPU: 100 % = un núcleo. RSS en MiB. NA = dato no medido.",
            "Los estados del resumen no certifican jugabilidad ni duración completa de la prueba.",
            "",
            "| " + " | ".join(fields) + " |",
            "| " + " | ".join("---" for _ in fields) + " |",
        ]
        lines.extend("| " + " | ".join(display(row[field]) for field in fields) + " |" for row in rows)
        path = Path(args.markdown)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--warmup", type=float, default=10)
    parser.add_argument("--duration", type=float, default=60)
    parser.add_argument("--tick-goal-ms", type=float, default=16.7)
    parser.add_argument("--csv")
    parser.add_argument("--markdown")
    args = parser.parse_args()
    if (not math.isfinite(args.warmup) or args.warmup < 0
            or not math.isfinite(args.duration) or args.duration <= 0
            or not math.isfinite(args.tick_goal_ms) or args.tick_goal_ms <= 0):
        parser.error("warmup must be nonnegative; duration and tick goal must be positive and finite")
    try:
        groups = collect(args.inputs, args.warmup, args.duration)
        rows = summarize(groups, args.tick_goal_ms)
        write_outputs(rows, args)
    except (OSError, ValueError, OverflowError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps({"summary": rows}, ensure_ascii=False, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
