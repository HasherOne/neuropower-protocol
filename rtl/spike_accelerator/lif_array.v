// SPDX-License-Identifier: Apache-2.0
// Time-multiplexed LIF array: NP_N neurons, NP_N×NP_N 4-bit synapses

`timescale 1ns / 1ps

module lif_array #(
    parameter integer NP_N      = 256,
    parameter integer V_WIDTH   = 16,
    parameter integer THR_RESET = 64
) (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 w_we,
    input  wire [15:0]          w_addr,
    input  wire [7:0]           w_wdata,

    input  wire                 clear_state,
    input  wire                 start_infer,
    input  wire [NP_N-1:0]      input_spikes,

    output reg                  busy,
    output reg                  done,
    output reg  [NP_N-1:0]      output_spikes,
    output reg  [7:0]           best_class,
    output reg  [7:0]           best_count
);

    localparam integer WBYTES = (NP_N * NP_N) / 2;
    localparam integer IDX_W  = 8;
    localparam [IDX_W-1:0] LAST = NP_N - 1;

    reg [7:0]                weight_mem [0:WBYTES-1];
    reg signed [V_WIDTH-1:0] v_mem [0:NP_N-1];
    reg [7:0]                spike_count [0:NP_N-1];
    reg signed [V_WIDTH-1:0] threshold;

    localparam [1:0] S_IDLE   = 2'd0;
    localparam [1:0] S_ACCUM  = 2'd1;
    localparam [1:0] S_FIRE   = 2'd2;
    localparam [1:0] S_ARGMAX = 2'd3;

    reg [1:0]       state;
    reg [IDX_W-1:0] src;
    reg [IDX_W-1:0] dst;
    reg [IDX_W-1:0] arg_i;
    reg [NP_N-1:0]  in_latched;
    reg [NP_N-1:0]  out_acc;
    reg [7:0]       arg_best_i;
    reg [7:0]       arg_best_c;

    integer ki;

    function [3:0] get_nibble;
        input [IDX_W-1:0] s;
        input [IDX_W-1:0] d;
        reg [15:0] lin;
        reg [7:0]  byt;
        begin
            lin = s * NP_N + d;
            byt = weight_mem[lin[15:1]];
            if (lin[0] == 1'b0)
                get_nibble = byt[3:0];
            else
                get_nibble = byt[7:4];
        end
    endfunction

    function signed [V_WIDTH-1:0] sext4;
        input [3:0] w;
        begin
            sext4 = {{(V_WIDTH-4){w[3]}}, w};
        end
    endfunction

    wire [3:0]                nib   = get_nibble(src, dst);
    wire signed [V_WIDTH-1:0] syn   = sext4(nib);
    wire signed [V_WIDTH-1:0] v_cur = v_mem[dst];
    wire signed [V_WIDTH-1:0] v_add = v_cur + syn;

    wire signed [V_WIDTH-1:0] v_fire_out;
    wire                      fire_pulse;

    lif_neuron #(
        .V_WIDTH(V_WIDTH),
        .LEAK_SHIFT(3)
    ) u_fire_lif (
        .v_in(v_cur),
        .syn_current({V_WIDTH{1'b0}}),
        .threshold(threshold),
        .enable(state == S_FIRE),
        .v_out(v_fire_out),
        .spike(fire_pulse)
    );

    always @(posedge clk) begin
        if (w_we)
            weight_mem[w_addr] <= w_wdata;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            src           <= {IDX_W{1'b0}};
            dst           <= {IDX_W{1'b0}};
            arg_i         <= {IDX_W{1'b0}};
            in_latched    <= {NP_N{1'b0}};
            out_acc       <= {NP_N{1'b0}};
            output_spikes <= {NP_N{1'b0}};
            best_class    <= 8'd0;
            best_count    <= 8'd0;
            threshold     <= THR_RESET;
            arg_best_i    <= 8'd0;
            arg_best_c    <= 8'd0;
            for (ki = 0; ki < NP_N; ki = ki + 1) begin
                v_mem[ki]       <= {V_WIDTH{1'b0}};
                spike_count[ki] <= 8'd0;
            end
        end else begin
            done <= 1'b0;

            if (clear_state) begin
                for (ki = 0; ki < NP_N; ki = ki + 1) begin
                    v_mem[ki]       <= {V_WIDTH{1'b0}};
                    spike_count[ki] <= 8'd0;
                end
                out_acc       <= {NP_N{1'b0}};
                output_spikes <= {NP_N{1'b0}};
                best_class    <= 8'd0;
                best_count    <= 8'd0;
            end

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_infer) begin
                        in_latched <= input_spikes;
                        out_acc    <= {NP_N{1'b0}};
                        src        <= {IDX_W{1'b0}};
                        dst        <= {IDX_W{1'b0}};
                        busy       <= 1'b1;
                        state      <= S_ACCUM;
                    end
                end

                S_ACCUM: begin
                    if (in_latched[src])
                        v_mem[dst] <= v_add;

                    if (dst == LAST) begin
                        dst <= {IDX_W{1'b0}};
                        if (src == LAST) begin
                            src   <= {IDX_W{1'b0}};
                            state <= S_FIRE;
                        end else begin
                            src <= src + 1'b1;
                        end
                    end else begin
                        dst <= dst + 1'b1;
                    end
                end

                S_FIRE: begin
                    v_mem[dst] <= v_fire_out;
                    if (fire_pulse) begin
                        out_acc[dst]     <= 1'b1;
                        spike_count[dst] <= spike_count[dst] + 8'd1;
                    end

                    if (dst == LAST) begin
                        output_spikes <= out_acc;
                        if (fire_pulse)
                            output_spikes[dst] <= 1'b1;
                        arg_i      <= {IDX_W{1'b0}};
                        arg_best_i <= 8'd0;
                        arg_best_c <= 8'd0;
                        dst        <= {IDX_W{1'b0}};
                        state      <= S_ARGMAX;
                    end else begin
                        dst <= dst + 1'b1;
                    end
                end

                S_ARGMAX: begin
                    begin : arg_blk
                        reg [7:0] bi, bc, cur;
                        cur = spike_count[arg_i];
                        if (arg_i == {IDX_W{1'b0}}) begin
                            bi = 8'd0;
                            bc = cur;
                        end else begin
                            bi = arg_best_i;
                            bc = arg_best_c;
                            if (cur > bc) begin
                                bi = arg_i[7:0];
                                bc = cur;
                            end
                        end
                        arg_best_i <= bi;
                        arg_best_c <= bc;
                        if (arg_i == LAST) begin
                            best_class <= bi;
                            best_count <= bc;
                            busy       <= 1'b0;
                            done       <= 1'b1;
                            state      <= S_IDLE;
                        end else begin
                            arg_i <= arg_i + 1'b1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
