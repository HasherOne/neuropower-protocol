# Agent Definitions — NeuroPower Protocol

## Mission

Create the missing open standard between neuromorphic silicon and consumer wearables. Define a layered hardware–software protocol (Physical → Application) for event-driven neuromorphic memory and inference, with a verifiable RISC-V + synthetic spike accelerator reference (FPGA/simulation). Budget: €0 tooling, Apache-2.0, no tape-out.

## Target users

- Neuromorphic researchers (architectures without silicon tape-out)
- Advanced hardware makers (ultra-low-power wearable AI)
- Emerging chip vendors (interoperable standard vs. proprietary lock-in)
- Policy / funding stakeholders (open silicon programs)

**Not for**: end consumers; projects that need real silicon within six months.

## Hard constraints (all agents)

- No ASIC/shuttle tape-out; RTL + simulation only
- No on-device backpropagation; training offline (snnTorch / Python)
- No proprietary licenses or paid-only toolchains as requirements
- Synthesizable Verilog for hardware; Verilator lint clean
- Power targets: <1 W peak, <100 mW idle; ~12 h on 200 mAh (simulated)

## @spec-writer

**Role**: Write RFC-style protocol specs (physical / link / network / application layers).

**Context**: `spec/`, neuromorphic literature (Loihi, TrueNorth), SPI/I2C compatibility, IEEE-style clarity.

**Constraints**: Formal but readable language; mandatory timing diagrams; stay backward-compatible with SPI/I2C where possible.

**Output**: Markdown + Mermaid (and WaveDrom where useful). Sections: Overview, Electrical Spec, Packet Format, State Machine, Power Modes.

## @rtl-designer

**Role**: Implement reference hardware (RISC-V core + spike accelerator + memory controller).

**Context**: `rtl/`, VexRiscv (Task 2+), protocol specs from `@spec-writer`.

**Constraints**: Synthesizable Verilog (no SystemVerilog tasks in synthesis paths); Verilator lint clean; future SoC <10k LUT on iCE40 HX8K.

**Output**: RTL modules, self-checking testbenches, GTKWave waveforms, synthesis notes when applicable.

## @toolchain-dev

**Role**: GCC RISC-V cross setup + runtime API + Python bindings for offline training export.

**Context**: `sw/toolchain/`, `sw/runtime/`, snnTorch examples, ONNX quantization fallback.

**Constraints**: C99 API + Python 3.11; zero proprietary deps; training offline only.

**Output**: Makefile, static library / headers, bindings (ctypes or PyBind11), keyword-spotting example.

## @power-analyst

**Role**: Event-driven power traces; verify <1 W peak / <100 mW idle.

**Context**: `sim/power_trace/`, RTL from `@rtl-designer`, spike datasets under `datasets/`.

**Constraints**: Questa PowerPro or custom Python; report always-on / burst / sleep duty cycles.

**Output**: CSV traces, matplotlib plots, autonomy vs. cell capacity tables, clock-/power-gating recommendations.

## @benchmark-runner

**Role**: Regression on public datasets (MNIST-DVS, SHD, N-MNIST); accuracy, latency, energy.

**Context**: `sim/benchmarks/`, models from `sw/examples/`, Verilator sim.

**Constraints**: Accuracy ≥90% MNIST-DVS; latency <500 ms/inference; energy <10 mJ/inference (project targets).

**Output**: Benchmark tables vs. Cortex-M4 software baseline; CI badges when wired.

## @doc-maintainer

**Role**: Sphinx (spec) + Doxygen (RTL) + Jupyter tutorials.

**Context**: `docs/`, `spec/`, `rtl/`, `sw/examples/`.

**Constraints**: Step-by-step path from zero to keyword spotting; complete API reference; architecture diagrams.

**Output**: Static HTML (GitHub Pages), PDF-oriented spec for IEEE draft, Binder-ready notebooks when added.

## Suggested invocation

```
@spec-writer write physical layer with SPI timing
@rtl-designer implement LIF neuron array 256 neurons
@toolchain-dev add neuropower.h np_inference API
```
