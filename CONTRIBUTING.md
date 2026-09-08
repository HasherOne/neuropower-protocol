# Contributing to NeuroPower Protocol

## Principles

- Spec and RTL stay **open** (Apache-2.0). No proprietary dependencies.
- **No silicon tape-out** in this repo — Verilator-verifiable RTL only.
- Training stays **offline** (Python / snnTorch). On-device path is inference only.
- One **logical task per PR**; CI green before merge.

## Agent roles (Cursor)

Use role tags so changes stay scoped. Definitions live in [`AGENTS.md`](AGENTS.md) and [`.cursor/rules`](.cursor/rules/).

| Tag | Owns |
|-----|------|
| `@spec-writer` | `spec/` RFC-style layers |
| `@rtl-designer` | `rtl/`, Verilator testbenches |
| `@toolchain-dev` | `sw/toolchain/`, `sw/runtime/`, bindings |
| `@power-analyst` | `sim/power_trace/` |
| `@benchmark-runner` | `sim/benchmarks/`, accuracy/latency/energy |
| `@doc-maintainer` | `docs/`, Sphinx/Doxygen/tutorials |

Example: `@rtl-designer implement LIF neuron array 256 neurons`.

## Spec changes

1. Edit the relevant `spec/*.md` and diagrams under `spec/diagrams/`.
2. Keep Physical/Link backward-compatible with SPI Mode 0 + async spike lines where possible.
3. Update examples (binary packet dumps) when the packet format changes.
4. Open a PR titled `spec: …` and request review.

## RTL changes

1. Prefer synthesizable Verilog (avoid SystemVerilog tasks/functions in synthesis paths).
2. Keep Verilator lint clean (`make -C sim/verilator lint`).
3. Add or extend a self-checking testbench under `rtl/testbench/`.
4. Target resource awareness: future iCE40 HX8K **<10k LUT** for the full SoC.

## Software / examples

- C API: C99. Python: 3.11+, prefer PyBind11 for bindings when added.
- Do not add cloud-only or paid toolchain requirements.

## Commit / PR hygiene

- Clear English commit messages (why, not only what).
- PR description: what changed, how to test (`make -C sim/verilator test`).
- Do not commit VCD dumps, `obj_dir/`, secrets, or large raw datasets without discussion.

## Code of conduct (short)

Be respectful in issues and reviews. Technical disagreement is welcome; personal attacks are not.
