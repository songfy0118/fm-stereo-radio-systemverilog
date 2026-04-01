// demodulate: conjugate multiply + qarctan + gain, 2-cycle pipeline
module demodulate
    import fm_radio_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic signed [DW-1:0] real_in,
    input  logic signed [DW-1:0] imag_in,
    input  logic                 in_valid,
    output logic signed [DW-1:0] demod_out,
    output logic                 out_valid
);
    logic signed [DW-1:0] real_prev, imag_prev;

    // Stage 1: conjugate multiply (combinational)
    logic signed [DW-1:0] conj_r, conj_i;
    always_comb begin
        conj_r = dequantize(64'(real_prev) * 64'(real_in)) +
                 dequantize(64'(imag_prev) * 64'(imag_in));
        conj_i = dequantize(64'(real_prev) * 64'(imag_in)) -
                 dequantize(64'(imag_prev) * 64'(real_in));
    end

    // Stage 1 registered
    logic signed [DW-1:0] conj_r_reg, conj_i_reg;
    logic                 stage1_valid;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            real_prev    <= '0;
            imag_prev    <= '0;
            conj_r_reg   <= '0;
            conj_i_reg   <= '0;
            stage1_valid <= 1'b0;
        end else begin
            stage1_valid <= in_valid;
            if (in_valid) begin
                conj_r_reg <= conj_r;
                conj_i_reg <= conj_i;
                real_prev  <= real_in;
                imag_prev  <= imag_in;
            end
        end
    end

    // Stage 2: qarctan (single-cycle)
    logic signed [DW-1:0] atan_out;
    logic                 atan_valid;

    qarctan u_atan (
        .clk(clk), .rst(rst),
        .y_in(conj_i_reg), .x_in(conj_r_reg),
        .in_valid(stage1_valid),
        .angle_out(atan_out), .out_valid(atan_valid)
    );

    // Stage 3: gain multiply
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            demod_out <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= atan_valid;
            if (atan_valid)
                demod_out <= dequantize(64'(FM_DEMOD_GAIN) * 64'(atan_out));
        end
    end
endmodule
