// SPDX-License-Identifier: Apache-2.0
// Simple MMIO bridge for spike accelerator (stand-in for VexRiscv dBus)
// Word-addressed 32-bit bus, ready in 1 cycle (combinational read)

`timescale 1ns / 1ps

module np_mmio #(
    parameter integer NP_N = 256
) (
    input  wire        clk,
    input  wire        rst_n,

    // CPU-facing simple bus
    input  wire        req,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg         gnt,
    output reg  [31:0] rdata,

    // Weight port
    output reg         w_we,
    output reg  [15:0] w_addr,
    output reg  [7:0]  w_wdata,

    // Accel control
    output reg         clear_state,
    output reg         start_infer,
    output reg  [NP_N-1:0] input_spikes,
    input  wire        busy,
    input  wire        done,
    input  wire [NP_N-1:0] output_spikes,
    input  wire [7:0]  best_class,
    input  wire [7:0]  best_count
);

    // Register map (byte addresses)
    // 0x0000 CTRL: bit0=start, bit1=clear (write pulses)
    // 0x0004 STATUS: bit0=busy, bit1=done_sticky
    // 0x0008 BEST: {16'b0, best_count, best_class}
    // 0x0010 IN_SPIKES[0]  ... 32-bit words covering NP_N bits
    // 0x0090 OUT_SPIKES[0] ...
    // 0x8000 WEIGHT_BASE + byte offset (write-only, low 8 bits of wdata)

    localparam [31:0] ADDR_CTRL   = 32'h0000_0000;
    localparam [31:0] ADDR_STATUS = 32'h0000_0004;
    localparam [31:0] ADDR_BEST   = 32'h0000_0008;
    localparam [31:0] ADDR_IN0    = 32'h0000_0010;
    localparam [31:0] ADDR_OUT0   = 32'h0000_0090;
    localparam [31:0] ADDR_WBASE  = 32'h0000_8000;

    reg done_sticky;

    localparam integer NWORDS = (NP_N + 31) / 32;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gnt          <= 1'b0;
            rdata        <= 32'd0;
            w_we         <= 1'b0;
            w_addr       <= 16'd0;
            w_wdata      <= 8'd0;
            clear_state  <= 1'b0;
            start_infer  <= 1'b0;
            input_spikes <= {NP_N{1'b0}};
            done_sticky  <= 1'b0;
        end else begin
            gnt         <= 1'b0;
            w_we        <= 1'b0;
            clear_state <= 1'b0;
            start_infer <= 1'b0;

            if (done)
                done_sticky <= 1'b1;

            if (req) begin
                gnt <= 1'b1;
                if (we) begin
                    if (addr == ADDR_CTRL) begin
                        if (wdata[0]) begin
                            start_infer <= 1'b1;
                            done_sticky <= 1'b0;
                        end
                        if (wdata[1])
                            clear_state <= 1'b1;
                    end else if (addr >= ADDR_IN0 && addr < ADDR_IN0 + NWORDS * 4) begin
                        begin : wr_in
                            integer word_i, b;
                            word_i = (addr - ADDR_IN0) >> 2;
                            for (b = 0; b < 32; b = b + 1) begin
                                if (word_i * 32 + b < NP_N)
                                    input_spikes[word_i * 32 + b] <= wdata[b];
                            end
                        end
                    end else if (addr >= ADDR_WBASE && addr < ADDR_WBASE + (NP_N * NP_N) / 2) begin
                        w_we    <= 1'b1;
                        w_addr  <= addr[15:0] - ADDR_WBASE[15:0];
                        w_wdata <= wdata[7:0];
                    end
                end else begin
                    if (addr == ADDR_STATUS)
                        rdata <= {30'd0, done_sticky, busy};
                    else if (addr == ADDR_BEST)
                        rdata <= {16'd0, best_count, best_class};
                    else if (addr >= ADDR_OUT0 && addr < ADDR_OUT0 + NWORDS * 4) begin
                        begin : rd_out
                            integer word_i, b;
                            reg [31:0] tmp;
                            word_i = (addr - ADDR_OUT0) >> 2;
                            tmp = 32'd0;
                            for (b = 0; b < 32; b = b + 1) begin
                                if (word_i * 32 + b < NP_N)
                                    tmp[b] = output_spikes[word_i * 32 + b];
                            end
                            rdata <= tmp;
                        end
                    end else begin
                        rdata <= 32'd0;
                    end
                end
            end
        end
    end

endmodule
