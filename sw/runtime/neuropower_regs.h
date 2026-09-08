#ifndef NEUROPOWER_REGS_H
#define NEUROPOWER_REGS_H

/* MMIO map — must match rtl/core/np_mmio.v */

#define NP_ADDR_CTRL      0x00000000u
#define NP_CTRL_START     (1u << 0)
#define NP_CTRL_CLEAR     (1u << 1)

#define NP_ADDR_STATUS    0x00000004u
#define NP_STATUS_BUSY    (1u << 0)
#define NP_STATUS_DONE    (1u << 1)

#define NP_ADDR_BEST      0x00000008u
#define NP_ADDR_IN0       0x00000010u
#define NP_ADDR_OUT0      0x00000090u
#define NP_ADDR_WEIGHT    0x00008000u

#endif /* NEUROPOWER_REGS_H */
