# VexRiscv integration (Task 2)

## Status

Task 2 ships a **stable MMIO + LIF accelerator SoC stub** (`neuropower_soc.v`) with a simple 32-bit req/gnt bus. Full **VexRiscv** (SpinalHDL-generated RV32I) is wired through the same bus; generating the core requires SBT + Spinal on a developer machine and is not vendored as a multi-megabyte blob here.

## Bus contract (CPU → SoC)

| Signal | Dir (SoC) | Meaning |
|--------|-----------|---------|
| `cpu_req` | in | Transaction request |
| `cpu_we` | in | 1=write, 0=read |
| `cpu_addr` | in | Byte address |
| `cpu_wdata` | in | Write data |
| `cpu_gnt` | out | 1-cycle grant / completion |
| `cpu_rdata` | out | Read data (valid with gnt on reads) |

This matches a minimal VexRiscv **dBus** adapter (single-cycle memory).

## How to plug a generated VexRiscv

1. Generate a minimal RV32I config (no FPU, no M, small I$/D$ or none) from [VexRiscv](https://github.com/SpinalHDL/VexRiscv).
2. Place `VexRiscv.v` (and Spinal deps if any) under `rtl/core/vexriscv/generated/`.
3. Write `vexriscv_np_wrap.v` that maps dBus cmd/rsp onto `cpu_*`.
4. Instantiate wrap + `neuropower_soc` in a top-level for FPGA/sim.

Until then, **Verilator co-sim** drives `cpu_*` from C++ (software model of the host CPU / future firmware).

## Register map

See [`../../sw/runtime/neuropower.h`](../../sw/runtime/neuropower.h).
