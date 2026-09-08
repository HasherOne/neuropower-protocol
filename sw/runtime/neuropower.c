/* SPDX-License-Identifier: Apache-2.0 */
#include "neuropower.h"
#include "neuropower_regs.h"

#include <string.h>

int np_init(np_ctx_t *ctx) {
    if (!ctx)
        return -1;
    memset(ctx, 0, sizeof(*ctx));
    np_hal_write32(NP_ADDR_CTRL, NP_CTRL_CLEAR);
    np_hal_delay_cycles(4);
    ctx->initialized = 1;
    return 0;
}

int np_load_weights(np_ctx_t *ctx, const uint8_t *bytes, size_t len) {
    const size_t need = ((size_t)NP_N * (size_t)NP_N) / 2u;
    size_t i;
    if (!ctx || !ctx->initialized || !bytes)
        return -1;
    if (len < need)
        return -2;
    for (i = 0; i < need; i++)
        np_hal_write32(NP_ADDR_WEIGHT + (uint32_t)i, (uint32_t)bytes[i]);
    return 0;
}

int np_inference(np_ctx_t *ctx, const uint8_t *input_spike_bytes,
                 size_t input_bytes, uint8_t *out_class, uint8_t *out_count) {
    const size_t nbytes = (NP_N + 7u) / 8u;
    const size_t nwords = (NP_N + 31u) / 32u;
    size_t w;
    uint32_t status;
    uint32_t best;
    uint32_t guard;

    if (!ctx || !ctx->initialized || !input_spike_bytes)
        return -1;
    if (input_bytes < nbytes)
        return -2;

    for (w = 0; w < nwords; w++) {
        uint32_t word = 0;
        size_t b;
        for (b = 0; b < 4; b++) {
            size_t idx = w * 4u + b;
            if (idx < nbytes)
                word |= ((uint32_t)input_spike_bytes[idx]) << (8u * b);
        }
        np_hal_write32(NP_ADDR_IN0 + (uint32_t)(w * 4u), word);
    }

    np_hal_write32(NP_ADDR_CTRL, NP_CTRL_START);

    for (guard = 0; guard < 10000000u; guard++) {
        status = np_hal_read32(NP_ADDR_STATUS);
        if (status & NP_STATUS_DONE)
            break;
        np_hal_delay_cycles(1);
    }
    if (!(status & NP_STATUS_DONE))
        return -3;

    best = np_hal_read32(NP_ADDR_BEST);
    ctx->last_best = best;
    if (out_class)
        *out_class = (uint8_t)(best & 0xffu);
    if (out_count)
        *out_count = (uint8_t)((best >> 8) & 0xffu);
    return 0;
}
