#ifndef NEUROPOWER_H
#define NEUROPOWER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * NeuroPower runtime API (Task 2 skeleton).
 *
 * Bare-metal firmware will MMIO through np_hal_*; the Verilator co-sim
 * provides the same HAL from C++. Host unit tests may use a software model.
 */

#ifndef NP_N
#define NP_N 256
#endif

typedef struct np_ctx {
    int initialized;
    uint32_t last_best; /* {count[15:8], class[7:0]} packed from BEST reg */
} np_ctx_t;

/** Platform HAL — provided by firmware or sim */
void np_hal_write32(uint32_t addr, uint32_t data);
uint32_t np_hal_read32(uint32_t addr);
void np_hal_delay_cycles(uint32_t n);

/** Initialize accelerator (clear state). */
int np_init(np_ctx_t *ctx);

/**
 * Load packed 4-bit weights (2 nibbles per byte), row-major src*NP_N+dst.
 * @param bytes  length must be (NP_N * NP_N) / 2
 */
int np_load_weights(np_ctx_t *ctx, const uint8_t *bytes, size_t len);

/**
 * Run one inference window.
 * @param input_spikes  bit i = source neuron i spiked
 * @param out_class     optional; receives argmax class
 * @return 0 on success
 */
int np_inference(np_ctx_t *ctx, const uint8_t *input_spike_bytes,
                 size_t input_bytes, uint8_t *out_class, uint8_t *out_count);

#ifdef __cplusplus
}
#endif

#endif /* NEUROPOWER_H */
