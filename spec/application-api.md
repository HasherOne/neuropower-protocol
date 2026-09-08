# NeuroPower Protocol — Application API v0.1.0

**Status**: Draft (Tasks 2–5)  
**Depends on**: MMIO map; [Network Layer](network-layer.md) for multi-core later

## C API

Header: [`sw/runtime/neuropower.h`](../sw/runtime/neuropower.h)

```c
int np_init(np_ctx_t *ctx);
int np_load_weights(np_ctx_t *ctx, const uint8_t *bytes, size_t len);
int np_inference(np_ctx_t *ctx, const uint8_t *input_spike_bytes,
                 size_t input_bytes, uint8_t *out_class, uint8_t *out_count);
```

HAL: `np_hal_write32` / `np_hal_read32` / `np_hal_delay_cycles`.

## Registers

See [`sw/runtime/neuropower_regs.h`](../sw/runtime/neuropower_regs.h).

## Offline training

1. Train (`sw/examples/keyword_spotting_train.py`) → `.npw`
2. Validate (`sw/toolchain/flash_tool.py`)
3. Stream via `weight_loader` or MMIO `NP_ADDR_WEIGHT`

Training is **never** on-device backprop. Optional STDP updates use Link `weight_delta` (future).

## Python

ctypes / PyBind11 bindings TBD; for now call the converter and train scripts directly.
