// IIR filter: single-cycle, matches C iir() exactly
module iir #(
    parameter int TAPS = 2,
    parameter int DECIMATION = 1
)(
    input  logic        clk,
    input  logic        rst,
    input  logic signed [31:0] x_coeffs [0:TAPS-1],
    input  logic signed [31:0] y_coeffs [0:TAPS-1],
    input  logic signed [31:0] x_in,
    input  logic               x_valid,
    output logic signed [31:0] y_out,
    output logic               y_valid
);
    import fm_radio_pkg::*;

    logic signed [31:0] x_reg [0:TAPS-1];
    logic signed [31:0] y_reg [0:TAPS-1];

    // Compute new x and y arrays, then MAC
    logic signed [31:0] x_new [0:TAPS-1];
    logic signed [31:0] y_new [0:TAPS-1];
    logic signed [31:0] y1, y2;

    always_comb begin
        // Shift x, load new sample
        for (int j = TAPS-1; j >= 1; j--)
            x_new[j] = x_reg[j-1];
        x_new[0] = x_in;

        // Shift y
        for (int j = TAPS-1; j >= 1; j--)
            y_new[j] = y_reg[j-1];
        y_new[0] = '0; // placeholder, will be computed

        // MAC
        y1 = '0;
        y2 = '0;
        for (int i = 0; i < TAPS; i++) begin
            y1 = y1 + dequantize(64'(x_coeffs[i]) * 64'(x_new[i]));
            y2 = y2 + dequantize(64'(y_coeffs[i]) * 64'(y_new[i]));
        end
        y_new[0] = y1 + y2;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            y_out   <= '0;
            y_valid <= 1'b0;
            for (int i = 0; i < TAPS; i++) begin
                x_reg[i] <= '0;
                y_reg[i] <= '0;
            end
        end else begin
            y_valid <= 1'b0;
            if (x_valid) begin
                for (int i = 0; i < TAPS; i++) begin
                    x_reg[i] <= x_new[i];
                    y_reg[i] <= y_new[i];
                end
                y_out   <= y_new[TAPS-1];
                y_valid <= 1'b1;
            end
        end
    end
endmodule
