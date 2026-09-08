// SPDX-License-Identifier: Apache-2.0
// Simple MMIO bridge for spike accelerator (stand-in for VexRiscv dBus)
// Control/weight strobes are combinational with req so same-cycle consumers see them

`timescale 1ns / 1ps

module np_mmio #(
    parameter integer NP_N = 256
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        req,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg         gnt,
    output reg  [31:0] rdata,

    output wire        w_we,
    output wire [15:0] w_addr,
    output wire [7:0]  w_wdata,

    output wire        clear_state,
    output wire        start_infer,
    output reg  [NP_N-1:0] input_spikes,
    input  wire        busy,
    input  wire        done,
    input  wire [NP_N-1:0] output_spikes,
    input  wire [7:0]  best_class,
    input  wire [7:0]  best_count
);

    localparam [31:0] ADDR_CTRL   = 32'h0000_0000;
    localparam [31:0] ADDR_STATUS = 32'h0000_0004;
    localparam [31:0] ADDR_BEST   = 32'h0000_0008;
    localparam [31:0] ADDR_IN0    = 32'h0000_0010;
    localparam [31:0] ADDR_OUT0   = 32'h0000_0090;
    localparam [31:0] ADDR_WBASE  = 32'h0000_8000;
    localparam integer WBYTES     = (NP_N * NP_N) / 2;
    localparam integer NWORDS     = (NP_N + 31) / 32;

    reg done_sticky;

    wire ctrl_wr = req && we && (addr == ADDR_CTRL);
    wire weight_wr = req && we &&
                     (addr >= ADDR_WBASE) &&
                     (addr < (ADDR_WBASE + WBYTES));

    assign start_infer = ctrl_wr && wdata[0];
    assign clear_state = ctrl_wr && wdata[1];
    assign w_we        = weight_wr;
    assign w_addr      = addr[15:0] - ADDR_WBASE[15:0];
    assign w_wdata     = wdata[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gnt          <= 1'b0;
            rdata        <= 32'd0;
            input_spikes <= {NP_N{1'b0}};
            done_sticky  <= 1'b0;
        end else begin
            gnt <= 1'b0;

            if (done)
                done_sticky <= 1'b1;

            if (ctrl_wr && wdata[0])
                done_sticky <= 1'b0;

            if (req) begin
                gnt <= 1'b1;
                if (we) begin
                    if (addr >= ADDR_IN0 && addr < ADDR_IN0 + NWORDS * 4) begin
                        begin : wr_in
                            integer word_i, b;
                            word_i = (addr - ADDR_IN0) >> 2;
                            for (b = 0; b < 32; b = b + 1) begin
                                if (word_i * 32 + b < NP_N)
                                    input_spikes[word_i * 32 + b] <= wdata[b];
                            end
                        end
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
