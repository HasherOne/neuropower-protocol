# Getting Started — NeuroPower Protocol

## Prerequisites

| Tool | Why | Notes |
|------|-----|-------|
| Git | Clone / contribute | |
| Make | Build sim targets | GNU Make or compatible |
| [Verilator](https://www.veripool.org/verilator/) | RTL lint + cycle sim | 5.x recommended |
| C++ compiler | Verilator harness | g++ or clang++ with C++17 |
| Python 3.11+ | Goldens + training | `pip install -r sw/requirements.txt` |
| NumPy | Weight export / KWS train | required for Task 3 |

### Install hints

**Ubuntu / Debian**

```bash
sudo apt update
sudo apt install -y verilator g++ make git python3 python3-pip
pip install -r sw/requirements.txt
```

**Windows**

- Use WSL2 (Ubuntu) with the packages above, **or**
- MSYS2 / Chocolatey packages for `verilator` if available on your host

**macOS**

```bash
brew install verilator
```

## Clone and run

```bash
git clone <this-repo-url> neuropower-protocol
cd neuropower-protocol
```

### Without Verilator (Python)

```bash
pip install -r sw/requirements.txt
python sim/verilator/test_crc_golden.py
python sim/verilator/test_lif_golden.py
python sim/verilator/test_weight_loader_golden.py
python sw/examples/keyword_spotting_train.py --np-n 16 --min-acc 0.90
```

### Full RTL sim (Verilator)

On Linux, WSL2 Ubuntu, or CI:

```bash
make -C sim/verilator lint
make -C sim/verilator test-spi
make -C sim/verilator test-soc
```

Expected highlights:

```text
PASS: example 5.1 accepted
ALL PASS
...
PASS: inference class=5 count=1
ALL PASS (soc co-sim)
```

SoC co-sim uses `NP_N=16` and `THR_RESET=4` for a fast self-check. RTL default remains **NP_N=256**. See `rtl/core/vexriscv/README.md` for plugging a generated VexRiscv onto the same bus.

GitHub Actions (`.github/workflows/ci-rtl.yml`) runs goldens + lint + both sims.

Clean:

```bash
make -C sim/verilator clean
```

## Read next

1. [Physical Layer](../spec/physical-layer.md)
2. [Link Layer](../spec/link-layer.md)
3. [Application API](../spec/application-api.md) / [`sw/runtime/neuropower.h`](../sw/runtime/neuropower.h)

## Not ready yet

- Generated VexRiscv binary in-tree (bus + docs ready)
- Real SHD / GSC dataset download (synthetic KWS stand-in works offline)
- Power traces (Task 4)
- Full network/application RFC (Task 5)

Follow [CONTRIBUTING.md](../CONTRIBUTING.md) for PRs.
