// SPDX-License-Identifier: Apache-2.0
// Stream .npw blob into weight memory (emulated flash / host byte stream)

`timescale 1ns / 1ps

module weight_loader #(
    parameter integer NP_N = 256
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        byte_valid,
    input  wire [7:0]  byte_data,
    output wire        byte_ready,

    output reg         w_we,
    output reg  [15:0] w_addr,
    output reg  [7:0]  w_wdata,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [15:0] thr_out
);

    localparam integer EXP_PAY = (NP_N * NP_N) / 2;
    localparam [31:0] MAGIC = 32'h3157504E;

    localparam [1:0] S_IDLE    = 2'd0;
    localparam [1:0] S_HEADER  = 2'd1;
    localparam [1:0] S_PAYLOAD = 2'd2;
    localparam [1:0] S_FINISH  = 2'd3;

    reg [1:0]  state;
    reg [4:0]  hdr_cnt;
    reg [7:0]  hdr [0:15];
    reg [31:0] payload_len;
    reg [31:0] crc_expect;
    reg [31:0] crc_acc;
    reg [31:0] pay_cnt;

    assign byte_ready = (state == S_HEADER) || (state == S_PAYLOAD);

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0]  data;
        integer i;
        reg [31:0] c;
        begin
            c = crc_in ^ {24'd0, data};
            for (i = 0; i < 8; i = i + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 32'hEDB88320;
                else
                    c = (c >> 1);
            end
            crc32_byte = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            busy        <= 1'b0;
            done        <= 1'b0;
            error       <= 1'b0;
            w_we        <= 1'b0;
            w_addr      <= 16'd0;
            w_wdata     <= 8'd0;
            thr_out     <= 16'd0;
            hdr_cnt     <= 5'd0;
            payload_len <= 32'd0;
            crc_expect  <= 32'd0;
            crc_acc     <= 32'hFFFFFFFF;
            pay_cnt     <= 32'd0;
        end else begin
            done <= 1'b0;
            w_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        hdr_cnt <= 5'd0;
                        crc_acc <= 32'hFFFFFFFF;
                        pay_cnt <= 32'd0;
                        state   <= S_HEADER;
                    end
                end

                S_HEADER: begin
                    if (byte_valid && byte_ready) begin
                        hdr[hdr_cnt] <= byte_data;
                        if (hdr_cnt == 5'd15) begin
                            begin : parse
                                reg [31:0] magic_w, plen_w, crc_w;
                                reg [15:0] n_w, thr_w;
                                magic_w = {hdr[3], hdr[2], hdr[1], hdr[0]};
                                n_w     = {hdr[5], hdr[4]};
                                thr_w   = {hdr[7], hdr[6]};
                                plen_w  = {hdr[11], hdr[10], hdr[9], hdr[8]};
                                crc_w   = {byte_data, hdr[14], hdr[13], hdr[12]};

                                if (magic_w != MAGIC || n_w != NP_N || plen_w != EXP_PAY) begin
                                    error <= 1'b1;
                                    busy  <= 1'b0;
                                    state <= S_IDLE;
                                end else begin
                                    thr_out     <= thr_w;
                                    payload_len <= plen_w;
                                    crc_expect  <= crc_w;
                                    crc_acc     <= 32'hFFFFFFFF;
                                    pay_cnt     <= 32'd0;
                                    state       <= S_PAYLOAD;
                                end
                            end
                        end else begin
                            hdr_cnt <= hdr_cnt + 5'd1;
                        end
                    end
                end

                S_PAYLOAD: begin
                    if (byte_valid && byte_ready) begin
                        w_we    <= 1'b1;
                        w_addr  <= pay_cnt[15:0];
                        w_wdata <= byte_data;
                        crc_acc <= crc32_byte(crc_acc, byte_data);
                        if (pay_cnt + 1 == payload_len)
                            state <= S_FINISH;
                        else
                            pay_cnt <= pay_cnt + 1;
                    end
                end

                S_FINISH: begin
                    if ((crc_acc ^ 32'hFFFFFFFF) != crc_expect)
                        error <= 1'b1;
                    else
                        done <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
