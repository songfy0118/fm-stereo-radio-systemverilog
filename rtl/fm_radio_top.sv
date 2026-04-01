// fm_radio_top: all modules are single-cycle, pipeline flows naturally
// Demod has 3-cycle latency (conj_mul + atan + gain)
// Parallel paths (pilot, lmr_bp, lpr) all start from demod output
// Pilot path: BPF(1cy) + square(1cy) + HP(1cy) = 3 extra cycles
// LMR BP path: BPF(1cy) = 1 cycle, then waits for pilot via FIFO
// LPR path: LPF decim8(1cy), then waits for LMR via FIFO
module fm_radio_top
    import fm_radio_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  iq_byte_in,
    input  logic        iq_byte_valid,
    output logic signed [DW-1:0] left_audio_out,
    output logic signed [DW-1:0] right_audio_out,
    output logic                 audio_valid
);

    // Stage 1: read_iq
    logic signed [DW-1:0] iq_i, iq_q;
    logic iq_valid;

    read_iq u_read_iq (
        .clk(clk), .rst(rst),
        .byte_in(iq_byte_in), .byte_valid(iq_byte_valid),
        .i_out(iq_i), .q_out(iq_q), .iq_valid(iq_valid)
    );

    // Stage 2: Channel LPF
    logic signed [DW-1:0] ch_i, ch_q;
    logic ch_valid;

    fir_cmplx #(.TAPS(CHANNEL_TAPS)) u_channel_lpf (
        .clk(clk), .rst(rst),
        .h_real(CHANNEL_COEFFS), .h_imag('{default: '0}),
        .x_real_in(iq_i), .x_imag_in(iq_q), .x_valid(iq_valid),
        .y_real_out(ch_i), .y_imag_out(ch_q), .y_valid(ch_valid)
    );

    // Stage 3: Demodulator (3 cycles: conj_mul + atan + gain)
    logic signed [DW-1:0] demod_data;
    logic demod_valid;

    demodulate u_demod (
        .clk(clk), .rst(rst),
        .real_in(ch_i), .imag_in(ch_q), .in_valid(ch_valid),
        .demod_out(demod_data), .out_valid(demod_valid)
    );

    // Stage 4a: L+R LPF (decim=8)
    logic signed [DW-1:0] audio_lpr;
    logic lpr_valid;

    fir #(.TAPS(AUDIO_LPR_TAPS), .DECIMATION(AUDIO_DECIM)) u_lpr_lpf (
        .clk(clk), .rst(rst), .coeff(AUDIO_LPR_COEFFS),
        .x_in(demod_data), .x_valid(demod_valid),
        .y_out(audio_lpr), .y_valid(lpr_valid)
    );

    // Stage 4b: Pilot BPF (1 cycle)
    logic signed [DW-1:0] pilot_bp;
    logic pilot_bp_valid;

    fir #(.TAPS(BP_PILOT_TAPS), .DECIMATION(1)) u_pilot_bpf (
        .clk(clk), .rst(rst), .coeff(BP_PILOT_COEFFS),
        .x_in(demod_data), .x_valid(demod_valid),
        .y_out(pilot_bp), .y_valid(pilot_bp_valid)
    );

    // Stage 4c: L-R BPF (1 cycle)
    logic signed [DW-1:0] lmr_bp;
    logic lmr_bp_valid;

    fir #(.TAPS(BP_LMR_TAPS), .DECIMATION(1)) u_lmr_bpf (
        .clk(clk), .rst(rst), .coeff(BP_LMR_COEFFS),
        .x_in(demod_data), .x_valid(demod_valid),
        .y_out(lmr_bp), .y_valid(lmr_bp_valid)
    );

    // FIFO: buffer L-R BPF output (waits for pilot path: +2 cycles)
    logic signed [DW-1:0] lmr_bp_fifo_data;
    logic lmr_bp_fifo_empty;
    logic lmr_bp_fifo_rd;

    fifo #(.WIDTH(DW), .DEPTH(64)) u_lmr_bp_fifo (
        .clk(clk), .rst(rst),
        .wr_data(lmr_bp), .wr_en(lmr_bp_valid), .full(),
        .rd_data(lmr_bp_fifo_data), .rd_en(lmr_bp_fifo_rd), .empty(lmr_bp_fifo_empty),
        .count()
    );

    // Stage 5: Square pilot
    logic signed [DW-1:0] pilot_sq;
    logic pilot_sq_valid;

    multiply u_pilot_square (
        .clk(clk), .rst(rst),
        .a_in(pilot_bp), .b_in(pilot_bp), .in_valid(pilot_bp_valid),
        .out(pilot_sq), .out_valid(pilot_sq_valid)
    );

    // Stage 6: HP filter
    logic signed [DW-1:0] pilot_hp;
    logic pilot_hp_valid;

    fir #(.TAPS(HP_TAPS), .DECIMATION(1)) u_hp_filter (
        .clk(clk), .rst(rst), .coeff(HP_COEFFS),
        .x_in(pilot_sq), .x_valid(pilot_sq_valid),
        .y_out(pilot_hp), .y_valid(pilot_hp_valid)
    );

    // Stage 7: Multiply HP pilot x L-R BPF
    assign lmr_bp_fifo_rd = pilot_hp_valid && !lmr_bp_fifo_empty;

    logic signed [DW-1:0] lmr_demod;
    logic lmr_demod_valid;

    multiply u_lmr_demod (
        .clk(clk), .rst(rst),
        .a_in(pilot_hp), .b_in(lmr_bp_fifo_data),
        .in_valid(pilot_hp_valid && !lmr_bp_fifo_empty),
        .out(lmr_demod), .out_valid(lmr_demod_valid)
    );

    // Stage 8: L-R LPF (decim=8)
    logic signed [DW-1:0] audio_lmr;
    logic lmr_valid;

    fir #(.TAPS(AUDIO_LMR_TAPS), .DECIMATION(AUDIO_DECIM)) u_lmr_lpf (
        .clk(clk), .rst(rst), .coeff(AUDIO_LMR_COEFFS),
        .x_in(lmr_demod), .x_valid(lmr_demod_valid),
        .y_out(audio_lmr), .y_valid(lmr_valid)
    );

    // FIFO: buffer L+R audio (waits for L-R path)
    logic signed [DW-1:0] lpr_fifo_data;
    logic lpr_fifo_empty;
    logic lpr_fifo_rd;

    fifo #(.WIDTH(DW), .DEPTH(64)) u_lpr_audio_fifo (
        .clk(clk), .rst(rst),
        .wr_data(audio_lpr), .wr_en(lpr_valid), .full(),
        .rd_data(lpr_fifo_data), .rd_en(lpr_fifo_rd), .empty(lpr_fifo_empty),
        .count()
    );

    // Stage 9: L/R separation
    assign lpr_fifo_rd = lmr_valid && !lpr_fifo_empty;

    logic signed [DW-1:0] left_raw, right_raw;
    logic lr_valid;

    add u_add_left (
        .clk(clk), .rst(rst),
        .a_in(lpr_fifo_data), .b_in(audio_lmr),
        .in_valid(lmr_valid && !lpr_fifo_empty),
        .out(left_raw), .out_valid(lr_valid)
    );

    sub u_sub_right (
        .clk(clk), .rst(rst),
        .a_in(lpr_fifo_data), .b_in(audio_lmr),
        .in_valid(lmr_valid && !lpr_fifo_empty),
        .out(right_raw), .out_valid()
    );

    // Stage 10: Deemphasis
    logic signed [DW-1:0] left_deemph, right_deemph;
    logic deemph_l_valid, deemph_r_valid;

    iir #(.TAPS(IIR_TAPS)) u_deemph_left (
        .clk(clk), .rst(rst),
        .x_coeffs(IIR_X_COEFFS), .y_coeffs(IIR_Y_COEFFS),
        .x_in(left_raw), .x_valid(lr_valid),
        .y_out(left_deemph), .y_valid(deemph_l_valid)
    );

    iir #(.TAPS(IIR_TAPS)) u_deemph_right (
        .clk(clk), .rst(rst),
        .x_coeffs(IIR_X_COEFFS), .y_coeffs(IIR_Y_COEFFS),
        .x_in(right_raw), .x_valid(lr_valid),
        .y_out(right_deemph), .y_valid(deemph_r_valid)
    );

    // Stage 11: Gain
    gain u_gain_left (
        .clk(clk), .rst(rst),
        .x_in(left_deemph), .in_valid(deemph_l_valid),
        .gain_val(32'(VOLUME_LEVEL)),
        .out(left_audio_out), .out_valid(audio_valid)
    );

    gain u_gain_right (
        .clk(clk), .rst(rst),
        .x_in(right_deemph), .in_valid(deemph_r_valid),
        .gain_val(32'(VOLUME_LEVEL)),
        .out(right_audio_out), .out_valid()
    );

endmodule
