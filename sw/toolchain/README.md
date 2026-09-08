# Software toolchain

## Weight pipeline (Task 3)

```bash
pip install -r ../requirements.txt
python ../examples/keyword_spotting_train.py --np-n 16 -o ../examples/kws_weights.npw
python flash_tool.py ../examples/kws_weights.npw
```

- Format: [weight_format.md](weight_format.md)
- Converter: [model_converter.py](model_converter.py)

## RISC-V firmware (later)

Cross-compile against [`../runtime/neuropower.h`](../runtime/neuropower.h):

- Toolchain: xPack / `gcc-riscv64-unknown-elf`
- Flags: `-march=rv32i -mabi=ilp32`

Verilator co-sim already exercises the C API via a C++ HAL (no cross-compiler in CI).
