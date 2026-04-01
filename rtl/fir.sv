// FIR filter: single-cycle MAC, matches C fir() exactly
//
// C behavior with decimation:
//   Collects DECIMATION samples, then:
//     shift x[] right by DECIMATION
//     load DECIMATION new samples (reversed)
//     y = sum(DEQUANTIZE(coeff[TAPS-j-1] * x[j]))
//
// For decim=1: shift 1, load 1, compute — every input produces output
// For decim=8: collect 8 inputs, shift 8, load 8, compute — 1 output per 8 inputs
//
// The MAC uses the x[] register BEFORE the shift (since shift and MAC
// happen "simultaneously" in the C code, but the C code shifts first then MACs).
// We need to shift first, then MAC on the NEW state.
// Solution: do shift+load in the same cycle as MAC, but MAC reads the NEW values.
// Use combinational logic for the shifted array.
module fir #(
    parameter int TAPS       = 32,
    parameter int DECIMATION = 1
)(
    input  logic        clk,
    input  logic        rst,
    input  logic signed [31:0] coeff [0:TAPS-1],
    input  logic signed [31:0] x_in,
    input  logic               x_valid,
    output logic signed [31:0] y_out,
    output logic               y_valid
);
    import fm_radio_pkg::*;

    logic signed [31:0] x [0:TAPS-1];
    logic signed [31:0] x_buf [0:DECIMATION-1];
    logic [$clog2(DECIMATION+1)-1:0] decim_cnt;

    // Shifted+loaded version of x for MAC computation
    logic signed [31:0] x_new [0:TAPS-1];

    // Build the new x array combinationally (after shift+load)
    always_comb begin
        // Shift right by DECIMATION
        for (int j = TAPS-1; j >= DECIMATION; j--)
            x_new[j] = x[j - DECIMATION];
        // Load new samples (reversed): x[DECIMATION-1-i] = x_buf[i]
        for (int i = 0; i < DECIMATION; i++) begin
            if (i < DECIMATION - 1)
                x_new[DECIMATION-1-i] = x_buf[i];
            else
                x_new[0] = x_in;  // Last sample is current x_in
        end
    end

    // Combinational MAC on new x
    logic signed [31:0] mac_result;
    always_comb begin
        mac_result = '0;
        for (int j = 0; j < TAPS; j++)
            mac_result = mac_result + dequantize(64'(coeff[TAPS-1-j]) * 64'(x_new[j]));
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            y_out     <= '0;
            y_valid   <= 1'b0;
            decim_cnt <= '0;
            for (int i = 0; i < TAPS; i++) x[i] <= '0;
            for (int i = 0; i < DECIMATION; i++) x_buf[i] <= '0;
        end else begin
            y_valid <= 1'b0;
            if (x_valid) begin
                if (decim_cnt < DECIMATION - 1) begin
                    // Collecting samples
                    x_buf[decim_cnt] <= x_in;
                    decim_cnt <= decim_cnt + 1;
                end else begin
                    // Got all DECIMATION samples — shift, load, MAC
                    for (int j = 0; j < TAPS; j++)
                        x[j] <= x_new[j];
                    y_out     <= mac_result;
                    y_valid   <= 1'b1;
                    decim_cnt <= '0;
                end
            end
        end
    end
endmodule
