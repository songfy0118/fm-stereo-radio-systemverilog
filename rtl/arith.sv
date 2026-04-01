module multiply
    import fm_radio_pkg::*;
(
    input  logic clk, rst,
    input  logic signed [DW-1:0] a_in, b_in,
    input  logic in_valid,
    output logic signed [DW-1:0] out,
    output logic out_valid
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin out <= '0; out_valid <= 0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) out <= dequantize(64'(a_in) * 64'(b_in));
        end
    end
endmodule

module add
    import fm_radio_pkg::*;
(
    input  logic clk, rst,
    input  logic signed [DW-1:0] a_in, b_in,
    input  logic in_valid,
    output logic signed [DW-1:0] out,
    output logic out_valid
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin out <= '0; out_valid <= 0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) out <= a_in + b_in;
        end
    end
endmodule

module sub
    import fm_radio_pkg::*;
(
    input  logic clk, rst,
    input  logic signed [DW-1:0] a_in, b_in,
    input  logic in_valid,
    output logic signed [DW-1:0] out,
    output logic out_valid
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin out <= '0; out_valid <= 0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) out <= a_in - b_in;
        end
    end
endmodule

module gain
    import fm_radio_pkg::*;
(
    input  logic clk, rst,
    input  logic signed [DW-1:0] x_in,
    input  logic in_valid,
    input  logic signed [DW-1:0] gain_val,
    output logic signed [DW-1:0] out,
    output logic out_valid
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin out <= '0; out_valid <= 0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) out <= dequantize(64'(x_in) * 64'(gain_val)) <<< (14 - BITS);
        end
    end
endmodule
