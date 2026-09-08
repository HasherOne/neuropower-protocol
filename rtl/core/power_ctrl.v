// SPDX-License-Identifier: Apache-2.0
// Simple event-driven power controller: gate accelerator clock after idle

`timescale 1ns / 1ps

module power_ctrl #(
    parameter integer IDLE_CYCLES = 1000  // ~10ms @ 100 kHz domain; sim uses smaller
) (
    input  wire clk,
    input  wire rst_n,

    input  wire activity,     // OR of busy / start / load
    input  wire force_awake,

    output reg  clk_en,       // 1 = accelerator domain enabled
    output reg  deep_sleep,
    output reg  [1:0] mode    // 0=active 1=idle_listen 2=deep_sleep
);

    localparam [1:0] M_ACTIVE = 2'd0;
    localparam [1:0] M_IDLE   = 2'd1;
    localparam [1:0] M_DEEP   = 2'd2;

    reg [31:0] idle_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idle_cnt   <= 32'd0;
            clk_en     <= 1'b1;
            deep_sleep <= 1'b0;
            mode       <= M_ACTIVE;
        end else begin
            if (force_awake || activity) begin
                idle_cnt   <= 32'd0;
                clk_en     <= 1'b1;
                deep_sleep <= 1'b0;
                mode       <= M_ACTIVE;
            end else if (idle_cnt >= IDLE_CYCLES) begin
                clk_en     <= 1'b0;
                deep_sleep <= 1'b1;
                mode       <= M_DEEP;
            end else begin
                idle_cnt <= idle_cnt + 32'd1;
                clk_en   <= 1'b1;
                mode     <= M_IDLE;
                deep_sleep <= 1'b0;
            end
        end
    end

endmodule
