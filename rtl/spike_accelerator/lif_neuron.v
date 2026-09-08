// SPDX-License-Identifier: Apache-2.0
// Single Leaky Integrate-and-Fire neuron (combinational update step)
// v' = leak(v) + syn_current; spike if v' >= threshold; then reset or subtract

`timescale 1ns / 1ps

module lif_neuron #(
    parameter integer V_WIDTH = 16,
    parameter integer THR_DEFAULT = 64,
    parameter integer LEAK_SHIFT = 3   // v = v - (v >> LEAK_SHIFT)
) (
    input  wire signed [V_WIDTH-1:0] v_in,
    input  wire signed [V_WIDTH-1:0] syn_current,
    input  wire signed [V_WIDTH-1:0] threshold,
    input  wire                      enable,
    output reg  signed [V_WIDTH-1:0] v_out,
    output reg                       spike
);
    reg signed [V_WIDTH-1:0] leaked;
    reg signed [V_WIDTH-1:0] integrated;

    always @* begin
        spike = 1'b0;
        v_out = v_in;
        if (enable) begin
            // Arithmetic right-shift leak toward 0 for signed values
            leaked     = v_in - (v_in >>> LEAK_SHIFT);
            integrated = leaked + syn_current;
            if (integrated >= threshold) begin
                spike = 1'b1;
                v_out = {V_WIDTH{1'b0}}; // hard reset
            end else begin
                v_out = integrated;
            end
        end
    end
endmodule
