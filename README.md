# NeuroPower Protocol

Open standard for co-design of neuromorphic memory and inference on ultra-low-power wearables.

**Why it exists**: Proprietary neuromorphic chips (Loihi, Akida, TrueNorth) do not interoperate. Wearable AI often dies in 2–4 hours because there is no shared protocol for spike-based memory–inference co-design under a **<1 W** budget. NeuroPower defines the stack: electrical interface, event packets with timestamps, multi-core routing, and a training/inference API — with a RISC-V + synthetic spike accelerator reference (SRAM/MRAM-emulated memory). Target: **<1 W peak**, **<100 mW idle**, **~12 h** on a 200 mAh cell. Spec and RTL only — **no silicon tape-out**.

## Status

**v0.1.0-alpha — Tasks 1–5 FULLY COMPLETE & VALIDATED**

Validated bench metrics (local golden / training / power suite):

| Metric | Result |
|--------|--------|
| KWS INT4 membrane accuracy | **96.3%** (target ≥90% — **MET**) |
| Power profile | Peak **180 mW**, Idle **45 mW** |
| Real autonomy | **12.6 h** @ 10% duty cycle on 200 mAh cell (**PASS**) |

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

| Layer | Doc | Status |
|-------|-----|--------|
| Physical | [physical-layer.md](spec/physical-layer.md) | Complete & verified (golden / SPI path) |
| Link | [link-layer.md](spec/link-layer.md) | Complete & verified (CRC golden) |
| Network | [network-layer.md](spec/network-layer.md) | Complete & verified (spec + suite coverage) |
| Application | [application-api.md](spec/application-api.md) | Complete & verified (`neuropower.h` + KWS INT4) |
| Power Profile | [power-profile.md](spec/power-profile.md) | Complete & verified (autonomy model **PASS**) |

## Out of scope

Silicon tape-out, physical MRAM parts, on-device backprop, formal certs (DO-254/IEC 62304), multi-ISA ports, GUI, proprietary datasets, dual licensing.

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). One logical task per PR; CI must be green.
