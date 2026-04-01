// qarctan: single-cycle combinational division using restoring algorithm
// No / operator used - division implemented as unrolled loop
// Same interface as original (no busy port)
module qarctan
    import fm_radio_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic signed [DW-1:0] y_in,
    input  logic signed [DW-1:0] x_in,
    input  logic                 in_valid,
    output logic signed [DW-1:0] angle_out,
    output logic                 out_valid
);

    // Combinational restoring division: |numer| / |denom|
    // Returns quotient with truncation toward zero (same as C integer division)
    function automatic logic [DW-1:0] div_unsigned(
        input logic [DW-1:0] dividend,
        input logic [DW-1:0] divisor
    );
        logic [DW-1:0] q;
        logic [DW-1:0] rem;
        logic [DW-1:0] new_rem;
        begin
            q   = '0;
            rem = '0;
            for (int i = DW-1; i >= 0; i--) begin
                new_rem = {rem[DW-2:0], dividend[i]};
                if (new_rem >= divisor) begin
                    rem = new_rem - divisor;
                    q[i] = 1'b1;
                end else begin
                    rem = new_rem;
                end
            end
            return q;
        end
    endfunction

    logic signed [DW-1:0] abs_y, numer, denom, r, angle;
    logic x_pos, y_neg;

    always_comb begin
        y_neg = (y_in < 0);
        x_pos = (x_in >= 0);
        abs_y = (y_in < 0) ? (-y_in + 1) : (y_in + 1);

        if (x_pos) begin
            numer = (x_in - abs_y) <<< BITS;
            denom = x_in + abs_y;
        end else begin
            numer = (x_in + abs_y) <<< BITS;
            denom = abs_y - x_in;
        end

        // Signed division using unsigned divider
        if (denom == 0) begin
            r = '0;
        end else begin
            automatic logic [DW-1:0] abs_numer = (numer < 0) ? -numer : numer;
            automatic logic [DW-1:0] abs_denom = (denom < 0) ? -denom : denom;
            automatic logic [DW-1:0] q = div_unsigned(abs_numer, abs_denom);
            automatic logic sign = numer[DW-1] ^ denom[DW-1];
            r = sign ? -$signed(q) : $signed(q);
        end

        if (x_pos)
            angle = QUAD1 - dequantize(64'(QUAD1) * 64'(r));
        else
            angle = QUAD3 - dequantize(64'(QUAD1) * 64'(r));

        if (y_neg)
            angle = -angle;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            angle_out <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid)
                angle_out <= angle;
        end
    end
endmodule
