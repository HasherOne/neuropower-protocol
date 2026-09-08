#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Software model of Task 2 LIF array (small N) — no Verilator required."""

from __future__ import annotations

NP_N = 16
THR = 4
LEAK_SHIFT = 3


def sext4(w: int) -> int:
    w &= 0xF
    return w - 16 if w & 0x8 else w


def pack_weight(mem: bytearray, src: int, dst: int, w4: int) -> None:
    lin = src * NP_N + dst
    bi = lin >> 1
    nib = w4 & 0xF
    b = mem[bi]
    if (lin & 1) == 0:
        b = (b & 0xF0) | nib
    else:
        b = (b & 0x0F) | (nib << 4)
    mem[bi] = b


def get_nibble(mem: bytes, src: int, dst: int) -> int:
    lin = src * NP_N + dst
    b = mem[lin >> 1]
    return (b & 0xF) if (lin & 1) == 0 else (b >> 4)


def infer(mem: bytes, input_spikes: list[int], v: list[int], counts: list[int]):
    # accum
    for src in range(NP_N):
        if not input_spikes[src]:
            continue
        for dst in range(NP_N):
            v[dst] += sext4(get_nibble(mem, src, dst))
    out = [0] * NP_N
    # fire
    for dst in range(NP_N):
        leaked = v[dst] - (v[dst] >> LEAK_SHIFT)
        if leaked >= THR:
            out[dst] = 1
            counts[dst] += 1
            v[dst] = 0
        else:
            v[dst] = leaked
    best_i = max(range(NP_N), key=lambda i: counts[i])
    return out, best_i, counts[best_i]


def main() -> int:
    mem = bytearray((NP_N * NP_N) // 2)
    pack_weight(mem, 0, 5, 7)
    v = [0] * NP_N
    counts = [0] * NP_N
    spikes = [0] * NP_N
    spikes[0] = 1
    _, cls, cnt = infer(mem, spikes, v, counts)
    if cls != 5 or cnt < 1:
        print(f"FAIL: class={cls} count={cnt}")
        return 1
    print(f"PASS: soft LIF class={cls} count={cnt}")
    print("ALL PASS (lif golden)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
