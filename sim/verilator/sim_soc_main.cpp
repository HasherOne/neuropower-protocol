// SPDX-License-Identifier: Apache-2.0
// Verilator co-sim: C++ CPU stand-in + neuropower.c against neuropower_soc

#include "Vneuropower_soc.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#ifndef NP_N
#define NP_N 16
#endif

#include "../../sw/runtime/neuropower.h"
#include "../../sw/runtime/neuropower_regs.h"

static vluint64_t main_time = 0;
double sc_time_stamp() { return static_cast<double>(main_time); }

static Vneuropower_soc* g_top = nullptr;

static void tick() {
    g_top->clk = 0;
    g_top->eval();
    main_time++;
    g_top->clk = 1;
    g_top->eval();
    main_time++;
}

static void settle(int n) {
    for (int i = 0; i < n; i++)
        tick();
}

static void bus_write(uint32_t addr, uint32_t data) {
    g_top->cpu_addr = addr;
    g_top->cpu_wdata = data;
    g_top->cpu_we = 1;
    g_top->cpu_req = 1;
    tick();
    g_top->cpu_req = 0;
    g_top->cpu_we = 0;
    tick();
}

static uint32_t bus_read(uint32_t addr) {
    g_top->cpu_addr = addr;
    g_top->cpu_we = 0;
    g_top->cpu_req = 1;
    tick();
    uint32_t v = g_top->cpu_rdata;
    g_top->cpu_req = 0;
    tick();
    return v;
}

extern "C" void np_hal_write32(uint32_t addr, uint32_t data) {
    bus_write(addr, data);
}

extern "C" uint32_t np_hal_read32(uint32_t addr) {
    return bus_read(addr);
}

extern "C" void np_hal_delay_cycles(uint32_t n) {
    settle(static_cast<int>(n));
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    g_top = new Vneuropower_soc;

    g_top->rst_n = 0;
    g_top->cpu_req = 0;
    g_top->cpu_we = 0;
    g_top->cpu_addr = 0;
    g_top->cpu_wdata = 0;
    g_top->load_start = 0;
    g_top->load_byte_valid = 0;
    g_top->load_byte_data = 0;
    settle(8);
    g_top->rst_n = 1;
    settle(8);

    int failures = 0;
    np_ctx_t ctx;

    if (np_init(&ctx) != 0) {
        std::printf("FAIL: np_init\n");
        failures++;
    } else {
        std::printf("PASS: np_init\n");
    }

    std::vector<uint8_t> weights((NP_N * NP_N) / 2, 0);
    {
        uint16_t lin = static_cast<uint16_t>(0 * NP_N + 5);
        uint16_t byte_i = static_cast<uint16_t>(lin >> 1);
        weights[byte_i] = 0x07; /* src0→dst5 weight +7 in low nibble */
    }
    if (np_load_weights(&ctx, weights.data(), weights.size()) != 0) {
        std::printf("FAIL: np_load_weights\n");
        failures++;
    } else {
        std::printf("PASS: np_load_weights\n");
    }

    std::vector<uint8_t> spikes((NP_N + 7) / 8, 0);
    spikes[0] = 0x01;

    uint8_t cls = 0xff, cnt = 0;
    int rc = np_inference(&ctx, spikes.data(), spikes.size(), &cls, &cnt);
    if (rc != 0) {
        std::printf("FAIL: np_inference rc=%d\n", rc);
        failures++;
    } else if (cls != 5) {
        std::printf("FAIL: expected class 5 got %u count %u\n", cls, cnt);
        failures++;
    } else {
        std::printf("PASS: inference class=%u count=%u\n", cls, cnt);
    }

    g_top->final();
    delete g_top;

    if (failures) {
        std::printf("FAILED: %d\n", failures);
        return 1;
    }
    std::printf("ALL PASS (soc co-sim)\n");
    return 0;
}
