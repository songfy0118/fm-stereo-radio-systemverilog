module div #(
    parameter DATA_WIDTH = 32
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  start,
    input  logic [DATA_WIDTH-1:0] dividend,
    input  logic [DATA_WIDTH-1:0] divisor,
    output logic [DATA_WIDTH-1:0] quotient,
    output logic [DATA_WIDTH-1:0] remainder,
    output logic                  done,
    output logic                  error
);

    function automatic logic [$clog2(DATA_WIDTH)-1:0] get_msb(input logic [DATA_WIDTH-1:0] val);
        logic [$clog2(DATA_WIDTH)-1:0] idx;
        begin
            idx = '0;
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (val[i]) idx = logic'($unsigned(i[$clog2(DATA_WIDTH)-1:0]));
            end
            return idx;
        end
    endfunction

    typedef enum logic [2:0] {INIT, FIND_MSB, CALC_SHIFT, SUB_ACCUM, WRITE} state_t;
    state_t cur_state, next_state;

    logic signed [DATA_WIDTH-1:0]         dividend_abs, dividend_abs_t;
    logic signed [DATA_WIDTH-1:0]         divisor_abs,  divisor_abs_t;
    logic signed [DATA_WIDTH-1:0]         quotient_acc, quotient_acc_t;
    logic signed [$clog2(DATA_WIDTH):0]   shift_diff;
    logic        [$clog2(DATA_WIDTH)-1:0] shift_amount, shift_amount_t;
    logic        [$clog2(DATA_WIDTH)-1:0] dividend_msb, dividend_msb_t;
    logic        [$clog2(DATA_WIDTH)-1:0] divisor_msb,  divisor_msb_t;
    logic                                 result_sign, result_sign_t;
    logic                                 error_flag, error_flag_t;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            dividend_abs <= '0;
            divisor_abs  <= '0;
            quotient_acc <= '0;
            shift_amount <= '0;
            dividend_msb <= '0;
            divisor_msb  <= '0;
            result_sign  <= 1'b0;
            error_flag   <= 1'b0;
            cur_state    <= INIT;
        end
        else begin
            dividend_abs <= dividend_abs_t;
            divisor_abs  <= divisor_abs_t;
            quotient_acc <= quotient_acc_t;
            shift_amount <= shift_amount_t;
            dividend_msb <= dividend_msb_t;
            divisor_msb  <= divisor_msb_t;
            result_sign  <= result_sign_t;
            error_flag   <= error_flag_t;
            cur_state    <= next_state;
        end
    end

    always_comb begin
        done           = 1'b0;
        quotient       = '0;
        remainder      = '0;
        error          = error_flag;
        dividend_abs_t = dividend_abs;
        divisor_abs_t  = divisor_abs;
        quotient_acc_t = quotient_acc;
        shift_amount_t = shift_amount;
        dividend_msb_t = dividend_msb;
        divisor_msb_t  = divisor_msb;
        result_sign_t  = result_sign;
        error_flag_t   = error_flag;
        next_state     = cur_state;

        case (cur_state)
            INIT: begin
                if (start == 1'b1) begin
                    dividend_abs_t = dividend[DATA_WIDTH-1] ? -$signed(dividend) : $signed(dividend);
                    divisor_abs_t  = divisor[DATA_WIDTH-1] ? -$signed(divisor) : $signed(divisor);
                    quotient_acc_t = '0;
                    shift_amount_t = '0;
                    error_flag_t   = 1'b0;
                    result_sign_t  = dividend[DATA_WIDTH-1] ^ divisor[DATA_WIDTH-1];

                    if (divisor == '0) begin
                        error_flag_t = 1'b1;
                        next_state   = WRITE;
                    end
                    else if (divisor == {{(DATA_WIDTH-1){1'b0}}, 1'b1}) begin
                        quotient_acc_t = dividend_abs_t;
                        dividend_abs_t = '0;
                        next_state     = WRITE;
                    end
                    else begin
                        next_state = FIND_MSB;
                    end
                end
                else begin
                    next_state = INIT;
                end
            end

            FIND_MSB: begin
                dividend_msb_t = get_msb(logic'($unsigned(dividend_abs)));
                divisor_msb_t  = get_msb(logic'($unsigned(divisor_abs)));

                if (dividend_abs < divisor_abs) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = CALC_SHIFT;
                end
            end

            CALC_SHIFT: begin
                shift_diff = $signed({1'b0, dividend_msb}) - $signed({1'b0, divisor_msb});

                if (shift_diff <= 0) begin
                    shift_amount_t = '0;
                end
                else begin
                    shift_amount_t = logic'($unsigned(shift_diff[$clog2(DATA_WIDTH)-1:0]));
                end

                if ((divisor_abs <<< shift_amount_t) > dividend_abs) begin
                    if (shift_amount_t != '0) begin
                        shift_amount_t = shift_amount_t - 1'b1;
                    end
                end

                next_state = SUB_ACCUM;
            end

            SUB_ACCUM: begin
                quotient_acc_t = quotient_acc + $signed({{(DATA_WIDTH-1){1'b0}},1'b1} <<< shift_amount);

                if (divisor_abs <= dividend_abs) begin
                    dividend_abs_t = dividend_abs - (divisor_abs <<< shift_amount);
                    next_state     = FIND_MSB;
                end
                else begin
                    next_state = WRITE;
                end
            end

            WRITE: begin
                if (error_flag == 1'b1) begin
                    quotient  = '0;
                    remainder = '0;
                end
                else begin
                    quotient  = result_sign ? -quotient_acc : quotient_acc;
                    remainder = dividend[DATA_WIDTH-1] ? -dividend_abs : dividend_abs;
                end

                done       = 1'b1;
                next_state = INIT;
            end

            default: begin
                error_flag_t = 1'b0;
                next_state   = INIT;
            end
        endcase
    end

endmodule
