#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Convert float / INT weight matrices to NeuroPower .npw blobs."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

import numpy as np

MAGIC = b"NPW1"
HEADER_FMT = "<4sHHiI"  # magic, np_n, thr, payload_len(i32), crc32
HEADER_SIZE = struct.calcsize(HEADER_FMT)


def quantize_int4(w: np.ndarray) -> np.ndarray:
    """Symmetric quantize to INT4 two's complement in [-8, 7]."""
    w = np.asarray(w, dtype=np.float64)
    max_abs = np.max(np.abs(w)) if w.size else 1.0
    if max_abs < 1e-12:
        return np.zeros_like(w, dtype=np.int8)
    scale = 7.0 / max_abs
    q = np.rint(w * scale).astype(np.int16)
    return np.clip(q, -8, 7).astype(np.int8)


def pack_nibbles(w_int4: np.ndarray) -> bytes:
    """Pack NP_N×NP_N INT4 into (N*N)/2 bytes (even dst → low nibble)."""
    n = w_int4.shape[0]
    assert w_int4.shape == (n, n)
    out = bytearray((n * n) // 2)
    for src in range(n):
        for dst in range(n):
            lin = src * n + dst
            nib = int(w_int4[src, dst]) & 0xF
            bi = lin >> 1
            if (lin & 1) == 0:
                out[bi] = (out[bi] & 0xF0) | nib
            else:
                out[bi] = (out[bi] & 0x0F) | (nib << 4)
    return bytes(out)


def unpack_nibbles(blob: bytes, n: int) -> np.ndarray:
    w = np.zeros((n, n), dtype=np.int8)
    for src in range(n):
        for dst in range(n):
            lin = src * n + dst
            b = blob[lin >> 1]
            nib = (b & 0xF) if (lin & 1) == 0 else (b >> 4)
            if nib & 0x8:
                nib -= 16
            w[src, dst] = nib
    return w


def build_npw(w: np.ndarray, thr: int = 4) -> bytes:
    n = w.shape[0]
    q = quantize_int4(w) if w.dtype.kind == "f" else np.clip(w, -8, 7).astype(np.int8)
    payload = pack_nibbles(q)
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    header = struct.pack(HEADER_FMT, MAGIC, n, int(thr), len(payload), crc)
    return header + payload


def parse_npw(data: bytes) -> tuple[int, int, np.ndarray]:
    magic, n, thr, plen, crc = struct.unpack(HEADER_FMT, data[:HEADER_SIZE])
    if magic != MAGIC:
        raise ValueError(f"bad magic {magic!r}")
    payload = data[HEADER_SIZE : HEADER_SIZE + plen]
    if len(payload) != plen:
        raise ValueError("truncated payload")
    if plen != (n * n) // 2:
        raise ValueError("payload_len mismatch")
    if (zlib.crc32(payload) & 0xFFFFFFFF) != crc:
        raise ValueError("CRC mismatch")
    return n, thr, unpack_nibbles(payload, n)


def pad_to_n(w: np.ndarray, n: int) -> np.ndarray:
    """Embed smaller square/rectangular weights into N×N (top-left)."""
    out = np.zeros((n, n), dtype=w.dtype)
    r, c = w.shape
    out[: min(r, n), : min(c, n)] = w[: min(r, n), : min(c, n)]
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Float/INT matrix → NeuroPower .npw")
    ap.add_argument("input", type=Path, help=".npy weight matrix (src, dst)")
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("--np-n", type=int, default=None, help="Pad to this side length")
    ap.add_argument("--thr", type=int, default=4)
    args = ap.parse_args()

    w = np.load(args.input)
    if w.ndim != 2:
        raise SystemExit("input must be 2-D")
    if args.np_n:
        w = pad_to_n(w, args.np_n)
    if w.shape[0] != w.shape[1]:
        n = max(w.shape)
        w = pad_to_n(w, n)
    blob = build_npw(w, thr=args.thr)
    args.output.write_bytes(blob)
    print(f"Wrote {args.output} ({len(blob)} bytes, N={w.shape[0]}, thr={args.thr})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
