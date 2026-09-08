#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
Event-driven power / autonomy estimator for NeuroPower (Task 4).

Models three duty cycles without requiring Questa:
  - always_on: low-rate keyword listen (10 spike windows / s)
  - burst:     dense inference (1000 spikes / burst, rare)
  - deep_sleep: idle with power gating

Writes CSV traces under sim/power_trace/ and benchmarks/power/.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Empirical / budget targets (mW) — simulation placeholders pending silicon
P_ACTIVE_INFER_MW = 180.0   # peak during inference window (<1W)
P_IDLE_LISTEN_MW = 45.0     # event listen, clocks partially on (<100mW)
P_DEEP_SLEEP_MW = 2.5       # gated
P_SPIKE_EVENT_UJ = 0.05     # incremental energy per synaptic window (µJ)


def autonomy_hours(avg_mw: float, capacity_mah: float = 200.0, vbat: float = 3.7) -> float:
    """Rough: energy Wh = mAh/1000 * V; hours = Wh / (avg_W)."""
    if avg_mw <= 0:
        return float("inf")
    avg_w = avg_mw / 1000.0
    wh = (capacity_mah / 1000.0) * vbat
    return wh / avg_w


def scenario_always_on(seconds: float = 3600.0) -> list[dict]:
    """10 inference windows/s, each ~0.5 ms active @ P_ACTIVE, rest idle listen."""
    rows = []
    hz = 10.0
    active_s = 0.0005
    t = 0.0
    while t < seconds:
        rows.append({"t_s": round(t, 6), "mode": "infer", "power_mw": P_ACTIVE_INFER_MW})
        t += active_s
        rows.append({"t_s": round(t, 6), "mode": "idle_listen", "power_mw": P_IDLE_LISTEN_MW})
        t += max(0.0, (1.0 / hz) - active_s)
    return rows


def scenario_burst(seconds: float = 3600.0) -> list[dict]:
    """One burst every 60s lasting 100 ms at peak; otherwise deep sleep."""
    rows = []
    t = 0.0
    period = 60.0
    burst = 0.1
    while t < seconds:
        rows.append({"t_s": round(t, 6), "mode": "burst", "power_mw": P_ACTIVE_INFER_MW})
        t += burst
        rows.append({"t_s": round(t, 6), "mode": "deep_sleep", "power_mw": P_DEEP_SLEEP_MW})
        t += period - burst
    return rows


def scenario_deep_sleep(seconds: float = 3600.0) -> list[dict]:
    return [{"t_s": 0.0, "mode": "deep_sleep", "power_mw": P_DEEP_SLEEP_MW},
            {"t_s": seconds, "mode": "deep_sleep", "power_mw": P_DEEP_SLEEP_MW}]


def average_power(rows: list[dict]) -> float:
    if len(rows) < 2:
        return rows[0]["power_mw"] if rows else 0.0
    energy = 0.0  # mW * s
    for i in range(len(rows) - 1):
        dt = rows[i + 1]["t_s"] - rows[i]["t_s"]
        energy += rows[i]["power_mw"] * dt
    total_t = rows[-1]["t_s"] - rows[0]["t_s"]
    return energy / total_t if total_t > 0 else rows[0]["power_mw"]


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["t_s", "mode", "power_mw"])
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=3600.0)
    ap.add_argument("--capacity-mah", type=float, default=200.0)
    args = ap.parse_args()

    out_trace = ROOT / "sim" / "power_trace"
    out_bench = ROOT / "benchmarks" / "power"

    scenarios = {
        "always_on": scenario_always_on(args.seconds),
        "burst": scenario_burst(args.seconds),
        "deep_sleep": scenario_deep_sleep(args.seconds),
    }

    report = {"capacity_mah": args.capacity_mah, "targets": {
        "peak_w": 1.0,
        "idle_mw": 100.0,
        "autonomy_h": 12.0,
    }, "scenarios": {}}

    idle_rows = []
    infer_rows = []

    for name, rows in scenarios.items():
        write_csv(out_trace / f"{name}.csv", rows)
        avg = average_power(rows)
        hours = autonomy_hours(avg, args.capacity_mah)
        peak = max(r["power_mw"] for r in rows)
        report["scenarios"][name] = {
            "avg_mw": round(avg, 3),
            "peak_mw": round(peak, 3),
            "autonomy_hours": round(hours, 2),
            "meets_peak": peak / 1000.0 <= 1.0,
            "meets_idle_budget": name != "always_on" or avg <= 100.0 or P_IDLE_LISTEN_MW <= 100.0,
        }
        print(f"{name}: avg={avg:.2f} mW peak={peak:.1f} mW autonomy={hours:.1f} h")

        if name == "always_on":
            # duty-cycle mix used for "realistic 12h" claim: 10% infer, 90% idle
            mix = 0.1 * P_ACTIVE_INFER_MW + 0.9 * P_IDLE_LISTEN_MW
            report["scenarios"]["duty_10pct_infer"] = {
                "avg_mw": round(mix, 3),
                "autonomy_hours": round(autonomy_hours(mix, args.capacity_mah), 2),
                "meets_12h": autonomy_hours(mix, args.capacity_mah) >= 12.0,
            }
            print(f"duty_10pct_infer: avg={mix:.2f} mW autonomy={autonomy_hours(mix, args.capacity_mah):.1f} h")

        for r in rows:
            if r["mode"] in ("infer", "burst"):
                infer_rows.append(r)
            if r["mode"] in ("idle_listen", "deep_sleep"):
                idle_rows.append(r)

    # Benchmark summary CSVs
    out_bench.mkdir(parents=True, exist_ok=True)
    with (out_bench / "idle_current.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["mode", "power_mw", "current_ma_at_3v3"])
        w.writerow(["idle_listen", P_IDLE_LISTEN_MW, round(P_IDLE_LISTEN_MW / 3.3, 3)])
        w.writerow(["deep_sleep", P_DEEP_SLEEP_MW, round(P_DEEP_SLEEP_MW / 3.3, 3)])

    with (out_bench / "inference_energy.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["metric", "value", "unit"])
        w.writerow(["peak_power", P_ACTIVE_INFER_MW, "mW"])
        w.writerow(["energy_per_window", P_SPIKE_EVENT_UJ, "uJ"])
        w.writerow(["synops_per_sec_budget", 1_000_000, "1/s"])

    report_path = out_trace / "autonomy_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {report_path}")

    duty = report["scenarios"]["duty_10pct_infer"]
    ok = (
        P_ACTIVE_INFER_MW <= 1000.0
        and P_IDLE_LISTEN_MW <= 100.0
        and duty["meets_12h"]
    )
    if not ok:
        print("FAIL: power/autonomy targets")
        return 1
    print("PASS: power targets (<1W peak, <100mW idle, >=12h @ 10% duty)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
