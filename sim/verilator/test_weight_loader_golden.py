#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Behavioral model of weight_loader + CRC checks (no Verilator)."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "toolchain"))
from model_converter import build_npw, parse_npw  # noqa: E402
import numpy as np


def crc32_hw(data: bytes) -> int:
    """Match weight_loader.v Ethernet CRC."""
    c = 0xFFFFFFFF
    for b in data:
        c ^= b
        for _ in range(8):
            if c & 1:
                c = (c >> 1) ^ 0xEDB88320
            else:
                c >>= 1
        c &= 0xFFFFFFFF
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF


def simulate_loader(blob: bytes, np_n: int) -> tuple[bool, bytes]:
    """Return (ok, weight_mem_bytes)."""
    if len(blob) < 16:
        return False, b""
    magic, n, thr, plen, crc = struct.unpack("<4sHHiI", blob[:16])
    if magic != b"NPW1" or n != np_n or plen != (np_n * np_n) // 2:
        return False, b""
    payload = blob[16 : 16 + plen]
    if len(payload) != plen:
        return False, b""
    if crc32_hw(payload) != crc:
        return False, b""
    if (zlib.crc32(payload) & 0xFFFFFFFF) != crc:
        return False, b""
    return True, payload


def main() -> int:
    n = 16
    w = np.zeros((n, n), dtype=np.float64)
    w[0, 5] = 7.0
    blob = build_npw(w, thr=4)
    ok, payload = simulate_loader(blob, n)
    if not ok:
        print("FAIL: loader simulation / CRC")
        return 1
    n2, thr, w2 = parse_npw(blob)
    if n2 != n or thr != 4 or int(w2[0, 5]) != 7:
        print("FAIL: parse roundtrip", w2[0, 5])
        return 1
    print(f"PASS: weight_loader golden CRC len={len(payload)}")
    print("ALL PASS (weight loader golden)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
