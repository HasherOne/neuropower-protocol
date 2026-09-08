// SPDX-License-Identifier: Apache-2.0
// Self-checking Verilog testbench for spi_spike_if (Icarus / documentation).
// Primary CI path uses Verilator + sim/verilator/sim_main.cpp

`timescale 1ns / 1ps

module tb_spi_spike_if;
    reg         clk;
    reg         rst_n;
    reg         sclk;
    reg         mosi;
    wire        miso;
    reg         cs_n;
    reg         spike_in;
    wire        spike_out;
    wire        pkt_valid;
    wire        pkt_crc_err;
    wire [7:0]  neuron_id;
    wire [15:0] timestamp;
    wire [3:0]  weight_delta;
    wire [3:0]  flags;
    wire        spike_in_seen;

    integer errors;

    spi_spike_if dut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .spike_in(spike_in),
        .spike_out(spike_out),
        .pkt_valid(pkt_valid),
        .pkt_crc_err(pkt_crc_err),
        .neuron_id(neuron_id),
        .timestamp(timestamp),
        .weight_delta(weight_delta),
        .flags(flags),
        .spike_in_seen(spike_in_seen)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    task spi_send_byte;
        input [7:0] data;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                mosi = data[i];
                #40; // setup before rise
                sclk = 1;
                #40;
                sclk = 0;
                #40;
            end
        end
    endtask

    task spi_send_frame;
        input [7:0] b0, b1, b2, b3, b4;
        begin
            cs_n = 0;
            #100;
            spi_send_byte(b0);
            spi_send_byte(b1);
            spi_send_byte(b2);
            spi_send_byte(b3);
            spi_send_byte(b4);
            #100;
            cs_n = 1;
            #200;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0;
        sclk = 0;
        mosi = 0;
        cs_n = 1;
        spike_in = 0;
        #100;
        rst_n = 1;
        #100;

        // Spec example 5.1: 2A 01 00 20 D9
        spi_send_frame(8'h2A, 8'h01, 8'h00, 8'h20, 8'hD9);
        #500;
        if (neuron_id !== 8'h2A || timestamp !== 16'h0100 ||
            weight_delta !== 4'h2 || flags !== 4'h0) begin
            $display("FAIL: decoded fields mismatch");
            errors = errors + 1;
        end else begin
            $display("PASS: example 5.1 fields");
        end

        // Bad CRC
        spi_send_frame(8'h2A, 8'h01, 8'h00, 8'h20, 8'h00);
        #500;

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED with %0d errors", errors);
        $finish;
    end
endmodule
