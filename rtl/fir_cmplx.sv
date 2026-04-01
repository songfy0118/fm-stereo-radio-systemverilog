// Complex FIR: single-cycle combinational MAC
module fir_cmplx #(
    parameter int TAPS       = 20,
    parameter int DECIMATION = 1
)(
    input  logic        clk,
    input  logic        rst,
    input  logic signed [31:0] h_real [0:TAPS-1],
    input  logic signed [31:0] h_imag [0:TAPS-1],
    input  logic signed [31:0] x_real_in,
    input  logic signed [31:0] x_imag_in,
    input  logic               x_valid,
    output logic signed [31:0] y_real_out,
    output logic signed [31:0] y_imag_out,
    output logic               y_valid
);
    import fm_radio_pkg::*;

    logic signed [31:0] xr [0:TAPS-1];
    logic signed [31:0] xi [0:TAPS-1];

    // New shifted arrays
    logic signed [31:0] xr_new [0:TAPS-1];
    logic signed [31:0] xi_new [0:TAPS-1];

    always_comb begin
        for (int j = TAPS-1; j >= 1; j--) begin
            xr_new[j] = xr[j-1];
            xi_new[j] = xi[j-1];
        end
        xr_new[0] = x_real_in;
        xi_new[0] = x_imag_in;
    end

    // Combinational MAC
    logic signed [31:0] mac_real, mac_imag;
    always_comb begin
        mac_real = '0;
        mac_imag = '0;
        for (int i = 0; i < TAPS; i++) begin
            mac_real = mac_real + dequantize(64'(h_real[i]) * 64'(xr_new[i]) - 64'(h_imag[i]) * 64'(xi_new[i]));
            mac_imag = mac_imag + dequantize(64'(h_real[i]) * 64'(xi_new[i]) - 64'(h_imag[i]) * 64'(xr_new[i]));
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            y_real_out <= '0;
            y_imag_out <= '0;
            y_valid    <= 1'b0;
            for (int i = 0; i < TAPS; i++) begin
                xr[i] <= '0;
                xi[i] <= '0;
            end
        end else begin
            y_valid <= 1'b0;
            if (x_valid) begin
                for (int j = 0; j < TAPS; j++) begin
                    xr[j] <= xr_new[j];
                    xi[j] <= xi_new[j];
                end
                y_real_out <= mac_real;
                y_imag_out <= mac_imag;
                y_valid    <= 1'b1;
            end
        end
    end
endmodule
