# NeuroPower Protocol

Open standard for co-design of neuromorphic memory and inference on ultra-low-power wearables.

**Why it exists**: Proprietary neuromorphic chips (Loihi, Akida, TrueNorth) do not interoperate. Wearable AI often dies in 2–4 hours because there is no shared protocol for spike-based memory–inference co-design under a **<1 W** budget. NeuroPower defines the stack: electrical interface, event packets with timestamps, multi-core routing, and a training/inference API — with a RISC-V + synthetic spike accelerator reference (SRAM/MRAM-emulated memory). Target: **<1 W peak**, **<100 mW idle**, **~12 h** on a 200 mAh cell. Spec and RTL only — **no silicon tape-out**.

## Status

**v0.1.0 — Tasks 1–5 skeleton complete** — Spec layers, SPI+LIF+loader+power_ctrl SoC, KWS INT4 export, power/autonomy model, Sphinx + IEEE draft stubs.

## Quick start

```bash
pip install -r sw/requirements.txt
python sim/verilator/test_crc_golden.py
python sim/verilator/test_lif_golden.py
python sim/verilator/test_weight_loader_golden.py
python sw/examples/keyword_spotting_train.py --np-n 16
make -C sim/verilator test   # requires Verilator (Linux/WSL/CI)
```

## Repository layout

| Path | Role |
|------|------|
| [`spec/`](spec/) | Protocol layers (Physical → Application) |
| [`rtl/`](rtl/) | SPI IF, LIF accelerator, MMIO SoC stub (VexRiscv bus contract) |
| [`sw/`](sw/) | Runtime, toolchain, examples, bindings |
| [`sim/`](sim/) | Verilator, power traces, benchmarks |
| [`docs/`](docs/) | Getting started, API, tutorials |
| [`AGENTS.md`](AGENTS.md) | Cursor agent roles (`@spec-writer`, …) |

## Spec map

- [Physical Layer](spec/physical-layer.md)
- [Link Layer](spec/link-layer.md)
- [Network Layer](spec/network-layer.md) — TBD Task 5
- [Application API](spec/application-api.md) — draft (`neuropower.h`)
- [Power Profile](spec/power-profile.md) — TBD Task 4/5

## Out of scope

Silicon tape-out, physical MRAM parts, on-device backprop, formal certs (DO-254/IEC 62304), multi-ISA ports, GUI, proprietary datasets, dual licensing.

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). One logical task per PR; CI must be green.
