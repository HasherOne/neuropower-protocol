#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Golden checks for Link Layer CRC-8 (spec/link-layer.md). Runs without Verilator."""

from __future__ import annotations


def crc8(data: bytes) -> int:
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ 0x07) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc


def main() -> int:
    failures = 0

    ex1 = bytes([0x2A, 0x01, 0x00, 0x20])
    if crc8(ex1) != 0xD9:
        print(f"FAIL: example 5.1 CRC got {crc8(ex1):02X} want D9")
        failures += 1
    else:
        print("PASS: example 5.1 CRC == 0xD9")

    ex2 = bytes([0x2A, 0x01, 0x00, 0x21])
    if crc8(ex2) != 0xDE:
        print(f"FAIL: example 5.2 CRC got {crc8(ex2):02X} want DE")
        failures += 1
    else:
        print("PASS: example 5.2 CRC == 0xDE")

    # Bit-serial must match byte-wise
    bits = []
    for b in ex1:
        for i in range(7, -1, -1):
            bits.append((b >> i) & 1)
    crc = 0
    for din in bits:
        if ((crc >> 7) ^ din) & 1:
            crc = (((crc << 1) & 0xFF) ^ 0x07)
        else:
            crc = (crc << 1) & 0xFF
    if crc != 0xD9:
        print(f"FAIL: bit-serial CRC {crc:02X}")
        failures += 1
    else:
        print("PASS: bit-serial CRC matches")

    if failures:
        print(f"FAILED: {failures}")
        return 1
    print("ALL PASS (golden)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
