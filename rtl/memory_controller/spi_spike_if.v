// SPDX-License-Identifier: Apache-2.0
// NeuroPower Protocol — SPI slave + Link Layer packet parser (Task 1)
// Packet: 5 bytes [neuron_id][timestamp BE][w_delta|flags][crc8] — see spec/link-layer.md

`timescale 1ns / 1ps

module spi_spike_if (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sclk,
    input  wire        mosi,
    output wire        miso,
    input  wire        cs_n,

    input  wire        spike_in,
    output reg         spike_out,

    output reg         pkt_valid,
    output reg         pkt_crc_err,
    output reg  [7:0]  neuron_id,
    output reg  [15:0] timestamp,
    output reg  [3:0]  weight_delta,
    output reg  [3:0]  flags,
    output reg         spike_in_seen
);

    reg [2:0] sclk_sync;
    reg [2:0] cs_sync;
    reg [2:0] mosi_sync;
    reg [2:0] spike_in_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync     <= 3'b000;
            cs_sync       <= 3'b111;
            mosi_sync     <= 3'b000;
            spike_in_sync <= 3'b000;
        end else begin
            sclk_sync     <= {sclk_sync[1:0], sclk};
            cs_sync       <= {cs_sync[1:0], cs_n};
            mosi_sync     <= {mosi_sync[1:0], mosi};
            spike_in_sync <= {spike_in_sync[1:0], spike_in};
        end
    end

    wire sclk_rise     = (sclk_sync[2:1] == 2'b01);
    wire cs_active     = ~cs_sync[1];
    wire cs_fall       = (cs_sync[2:1] == 2'b10);
    wire spike_in_rise = (spike_in_sync[2:1] == 2'b01);

    function [7:0] crc8_bit;
        input [7:0] crc_in;
        input       din;
        begin
            if (crc_in[7] ^ din)
                crc8_bit = {crc_in[6:0], 1'b0} ^ 8'h07;
            else
                crc8_bit = {crc_in[6:0], 1'b0};
        end
    endfunction

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_SHIFT = 2'd1;
    localparam [3:0] SPIKE_OUT_CLKS = 4'd8;

    reg [1:0]  state;
    reg [5:0]  bit_cnt;
    reg [39:0] shift_reg;
    reg [7:0]  crc_acc;
    reg        miso_r;
    reg [3:0]  spike_out_cnt;
    reg [39:0] frame_now;

    assign miso = miso_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            bit_cnt        <= 6'd0;
            shift_reg      <= 40'd0;
            crc_acc        <= 8'h00;
            miso_r         <= 1'b0;
            pkt_valid      <= 1'b0;
            pkt_crc_err    <= 1'b0;
            neuron_id      <= 8'h00;
            timestamp      <= 16'h0000;
            weight_delta   <= 4'h0;
            flags          <= 4'h0;
            spike_out      <= 1'b0;
            spike_out_cnt  <= 4'd0;
            spike_in_seen  <= 1'b0;
            frame_now      <= 40'd0;
        end else begin
            pkt_valid   <= 1'b0;
            pkt_crc_err <= 1'b0;

            if (spike_in_rise)
                spike_in_seen <= 1'b1;

            if (spike_out_cnt != 4'd0) begin
                spike_out_cnt <= spike_out_cnt - 4'd1;
                spike_out     <= 1'b1;
            end else begin
                spike_out <= 1'b0;
            end

            case (state)
                ST_IDLE: begin
                    bit_cnt   <= 6'd0;
                    crc_acc   <= 8'h00;
                    shift_reg <= 40'd0;
                    miso_r    <= 1'b0;
                    if (cs_fall)
                        state <= ST_SHIFT;
                end

                ST_SHIFT: begin
                    if (!cs_active) begin
                        state <= ST_IDLE;
                        if (bit_cnt != 6'd0)
                            pkt_crc_err <= 1'b1;
                    end else if (sclk_rise) begin
                        frame_now = {shift_reg[38:0], mosi_sync[1]};
                        shift_reg <= frame_now;

                        if (bit_cnt < 6'd32)
                            crc_acc <= crc8_bit(crc_acc, mosi_sync[1]);

                        if (bit_cnt == 6'd39) begin
                            if (frame_now[7:0] == crc_acc) begin
                                neuron_id    <= frame_now[39:32];
                                timestamp    <= frame_now[31:16];
                                weight_delta <= frame_now[15:12];
                                flags        <= frame_now[11:8];
                                pkt_valid    <= 1'b1;
                                if (!frame_now[11])
                                    spike_out_cnt <= SPIKE_OUT_CLKS;
                            end else begin
                                pkt_crc_err <= 1'b1;
                            end
                            state <= ST_IDLE;
                        end else begin
                            bit_cnt <= bit_cnt + 6'd1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
