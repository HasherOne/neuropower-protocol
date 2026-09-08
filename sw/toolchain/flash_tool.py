#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Upload a .npw blob (host helper). For Verilator, prefer streaming in the TB."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "toolchain"))
from model_converter import parse_npw  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate .npw and print load plan")
    ap.add_argument("npw", type=Path)
    ap.add_argument("--dump-hex", type=Path, default=None, help="Optional Intel-HEX-ish byte dump")
    args = ap.parse_args()

    data = args.npw.read_bytes()
    n, thr, w = parse_npw(data)
    print(f"OK: {args.npw} N={n} thr={thr} shape={w.shape} file={len(data)} bytes")
    print("Flash plan: assert load_start, stream all file bytes on load_byte_data")
    if args.dump_hex:
        args.dump_hex.write_text(
            "\n".join(f"{b:02X}" for b in data) + "\n", encoding="utf-8"
        )
        print(f"Wrote byte dump {args.dump_hex}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
