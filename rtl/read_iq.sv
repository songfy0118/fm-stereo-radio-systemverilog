module read_iq
    import fm_radio_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  byte_in,
    input  logic        byte_valid,
    output logic signed [DW-1:0] i_out,
    output logic signed [DW-1:0] q_out,
    output logic                 iq_valid
);
    logic [1:0] byte_cnt;
    logic [7:0] buf0, buf1, buf2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_cnt <= '0;
            iq_valid <= 1'b0;
            i_out <= '0;
            q_out <= '0;
        end else begin
            iq_valid <= 1'b0;
            if (byte_valid) begin
                case (byte_cnt)
                    2'd0: buf0 <= byte_in;
                    2'd1: buf1 <= byte_in;
                    2'd2: buf2 <= byte_in;
                    2'd3: begin
                        i_out    <= signed'({{16{buf1[7]}}, buf1, buf0}) <<< BITS;
                        q_out    <= signed'({{16{byte_in[7]}}, byte_in, buf2}) <<< BITS;
                        iq_valid <= 1'b1;
                    end
                endcase
                byte_cnt <= byte_cnt + 1'b1;
            end
        end
    end
endmodule
