// SPDX-License-Identifier: Apache-2.0
// Verilator C++ harness for spi_spike_if — Link Layer example 5.1

#include "Vspi_spike_if.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>

static vluint64_t main_time = 0;
double sc_time_stamp() { return static_cast<double>(main_time); }

struct PulseCount {
    int valid = 0;
    int crc_err = 0;
};

static void tick(Vspi_spike_if* top, PulseCount* pc) {
    top->clk = 0;
    top->eval();
    main_time++;
    top->clk = 1;
    top->eval();
    if (pc) {
        if (top->pkt_valid)
            pc->valid++;
        if (top->pkt_crc_err)
            pc->crc_err++;
    }
    main_time++;
}

static void settle(Vspi_spike_if* top, int n, PulseCount* pc) {
    for (int i = 0; i < n; i++)
        tick(top, pc);
}

static void spi_bit(Vspi_spike_if* top, int bit, PulseCount* pc) {
    top->mosi = bit ? 1 : 0;
    settle(top, 4, pc);
    top->sclk = 1;
    settle(top, 4, pc);
    top->sclk = 0;
    settle(top, 4, pc);
}

static void spi_byte(Vspi_spike_if* top, uint8_t data, PulseCount* pc) {
    for (int i = 7; i >= 0; i--)
        spi_bit(top, (data >> i) & 1, pc);
}

static void spi_frame(Vspi_spike_if* top, const uint8_t bytes[5], PulseCount* pc) {
    top->cs_n = 0;
    settle(top, 8, pc);
    for (int i = 0; i < 5; i++)
        spi_byte(top, bytes[i], pc);
    settle(top, 8, pc);
    top->cs_n = 1;
    settle(top, 16, pc);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vspi_spike_if* top = new Vspi_spike_if;

    top->rst_n = 0;
    top->sclk = 0;
    top->mosi = 0;
    top->cs_n = 1;
    top->spike_in = 0;
    settle(top, 10, nullptr);
    top->rst_n = 1;
    settle(top, 10, nullptr);

    int failures = 0;

    PulseCount good_pc;
    const uint8_t good[5] = {0x2A, 0x01, 0x00, 0x20, 0xD9};
    spi_frame(top, good, &good_pc);

    if (good_pc.valid < 1) {
        std::printf("FAIL: pkt_valid not seen for good frame (count=%d)\n", good_pc.valid);
        failures++;
    } else if (top->neuron_id != 0x2A || top->timestamp != 0x0100 ||
               top->weight_delta != 0x2 || top->flags != 0x0) {
        std::printf("FAIL: field decode nid=%02x ts=%04x wd=%x fl=%x\n",
                    top->neuron_id, top->timestamp, top->weight_delta, top->flags);
        failures++;
    } else {
        std::printf("PASS: example 5.1 accepted\n");
    }

    PulseCount bad_pc;
    const uint8_t bad[5] = {0x2A, 0x01, 0x00, 0x20, 0x00};
    spi_frame(top, bad, &bad_pc);
    if (bad_pc.valid > 0) {
        std::printf("FAIL: pkt_valid on bad CRC\n");
        failures++;
    }
    if (bad_pc.crc_err < 1) {
        std::printf("FAIL: pkt_crc_err not seen\n");
        failures++;
    } else {
        std::printf("PASS: bad CRC rejected\n");
    }

    top->spike_in = 1;
    settle(top, 6, nullptr);
    top->spike_in = 0;
    settle(top, 6, nullptr);
    if (!top->spike_in_seen) {
        std::printf("FAIL: spike_in_seen\n");
        failures++;
    } else {
        std::printf("PASS: spike_in edge captured\n");
    }

    top->final();
    delete top;

    if (failures) {
        std::printf("FAILED: %d\n", failures);
        return 1;
    }
    std::printf("ALL PASS\n");
    return 0;
}
