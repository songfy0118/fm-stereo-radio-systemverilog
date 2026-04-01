module fifo #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 256
)(
    input  logic             clk, rst,
    input  logic [WIDTH-1:0] wr_data,
    input  logic             wr_en,
    output logic             full,
    output logic [WIDTH-1:0] rd_data,
    input  logic             rd_en,
    output logic             empty,
    output logic [$clog2(DEPTH):0] count
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0] cnt;
    assign count = cnt;
    assign full  = (cnt == DEPTH);
    assign empty = (cnt == 0);
    assign rd_data = mem[rd_ptr];
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin wr_ptr <= '0; rd_ptr <= '0; cnt <= '0; end
        else begin
            if (wr_en && !full) begin mem[wr_ptr] <= wr_data; wr_ptr <= wr_ptr + 1; end
            if (rd_en && !empty) rd_ptr <= rd_ptr + 1;
            case ({wr_en && !full, rd_en && !empty})
                2'b10: cnt <= cnt + 1;
                2'b01: cnt <= cnt - 1;
                default: cnt <= cnt;
            endcase
        end
    end
endmodule
