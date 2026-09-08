// SPDX-License-Identifier: Apache-2.0
// NeuroPower SoC: MMIO + LIF + weight_loader + power_ctrl

`timescale 1ns / 1ps

module neuropower_soc #(
    parameter integer NP_N        = 256,
    parameter integer THR_RESET   = 64,
    parameter integer IDLE_CYCLES = 1000
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cpu_req,
    input  wire        cpu_we,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output wire        cpu_gnt,
    output wire [31:0] cpu_rdata,

    input  wire        load_start,
    input  wire        load_byte_valid,
    input  wire [7:0]  load_byte_data,
    output wire        load_byte_ready,
    output wire        load_busy,
    output wire        load_done,
    output wire        load_error,

    output wire        accel_busy,
    output wire        accel_done,
    output wire [7:0]  best_class,
    output wire [7:0]  best_count,
    output wire        pwr_clk_en,
    output wire        pwr_deep_sleep,
    output wire [1:0]  pwr_mode
);

    wire               mmio_w_we;
    wire [15:0]        mmio_w_addr;
    wire [7:0]         mmio_w_wdata;
    wire               ldr_w_we;
    wire [15:0]        ldr_w_addr;
    wire [7:0]         ldr_w_wdata;
    wire               clear_state;
    wire               start_infer;
    wire [NP_N-1:0]    input_spikes;
    wire [NP_N-1:0]    output_spikes;
    wire               busy;
    wire               done;
    wire [7:0]         best_c;
    wire [7:0]         best_n;
    wire               ldr_busy;
    wire [15:0]        ldr_thr_unused;

    wire               w_we    = ldr_busy ? ldr_w_we    : mmio_w_we;
    wire [15:0]        w_addr  = ldr_busy ? ldr_w_addr  : mmio_w_addr;
    wire [7:0]         w_wdata = ldr_busy ? ldr_w_wdata : mmio_w_wdata;

    wire               clk_en;
    wire               activity = busy | start_infer | ldr_busy | w_we | cpu_req | load_start;
    // Simulation clock gate (replace with integrated clock gate cell for FPGA/ASIC)
    wire               clk_accel = clk & clk_en;

    assign accel_busy     = busy;
    assign accel_done     = done;
    assign best_class     = best_c;
    assign best_count     = best_n;
    assign load_busy      = ldr_busy;
    assign pwr_clk_en     = clk_en;

    power_ctrl #(.IDLE_CYCLES(IDLE_CYCLES)) u_pwr (
        .clk(clk),
        .rst_n(rst_n),
        .activity(activity),
        .force_awake(1'b0),
        .clk_en(clk_en),
        .deep_sleep(pwr_deep_sleep),
        .mode(pwr_mode)
    );

    np_mmio #(.NP_N(NP_N)) u_mmio (
        .clk(clk),
        .rst_n(rst_n),
        .req(cpu_req),
        .we(cpu_we),
        .addr(cpu_addr),
        .wdata(cpu_wdata),
        .gnt(cpu_gnt),
        .rdata(cpu_rdata),
        .w_we(mmio_w_we),
        .w_addr(mmio_w_addr),
        .w_wdata(mmio_w_wdata),
        .clear_state(clear_state),
        .start_infer(start_infer),
        .input_spikes(input_spikes),
        .busy(busy),
        .done(done),
        .output_spikes(output_spikes),
        .best_class(best_c),
        .best_count(best_n)
    );

    weight_loader #(.NP_N(NP_N)) u_loader (
        .clk(clk),
        .rst_n(rst_n),
        .start(load_start),
        .byte_valid(load_byte_valid),
        .byte_data(load_byte_data),
        .byte_ready(load_byte_ready),
        .w_we(ldr_w_we),
        .w_addr(ldr_w_addr),
        .w_wdata(ldr_w_wdata),
        .busy(ldr_busy),
        .done(load_done),
        .error(load_error),
        .thr_out(ldr_thr_unused)
    );

    lif_array #(.NP_N(NP_N), .THR_RESET(THR_RESET)) u_lif (
        .clk(clk_accel),
        .rst_n(rst_n),
        .w_we(w_we),
        .w_addr(w_addr),
        .w_wdata(w_wdata),
        .clear_state(clear_state),
        .start_infer(start_infer),
        .input_spikes(input_spikes),
        .busy(busy),
        .done(done),
        .output_spikes(output_spikes),
        .best_class(best_c),
        .best_count(best_n)
    );

endmodule
