/*
 * FM Radio - Test Vector Generator
 * 
 * Modified from course-provided fm_radio.cpp to:
 *   1. Use a small subset of samples (TEST_SAMPLES) for RTL verification
 *   2. Dump every intermediate signal to .txt files
 *   3. Pure C (no audio output, no Linux sound headers)
 *
 * Build:  gcc -o fm_radio_test fm_radio_test.c -lm
 * Run:    ./fm_radio_test <usrp.dat subset file>
 *
 * The usrp.dat subset can be created with:
 *   dd if=usrp.dat of=usrp_subset.dat bs=1 count=$((TEST_SAMPLES*4))
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

/* ── Quantization (matches fm_radio.h exactly) ── */
#define BITS            10
#define QUANT_VAL       (1 << BITS)          /* 1024 */
#define QUANTIZE_F(f)   ((int)((float)(f) * (float)QUANT_VAL))
#define QUANTIZE_I(i)   ((int)((int)(i) * (int)QUANT_VAL))
#define DEQUANTIZE(i)   ((int)((int)(i) / (int)QUANT_VAL))

/* ── Constants ── */
#define PI              3.1415926535897932384626433832795f
#define ADC_RATE        64000000
#define USRP_DECIM      250
#define QUAD_RATE       (ADC_RATE / USRP_DECIM)         /* 256000 */
#define AUDIO_DECIM     8
#define AUDIO_RATE      (QUAD_RATE / AUDIO_DECIM)        /* 32000  */
#define VOLUME_LEVEL    QUANTIZE_F(1.0f)
#define MAX_DEV         55000.0f
#define FM_DEMOD_GAIN   QUANTIZE_F((float)QUAD_RATE / (2.0f * PI * MAX_DEV))
#define TAU             0.000075f
#define W_PP            0.21140067f
#define MAX_TAPS        32

/* ── Test size: use 256 IQ samples → 32 audio samples ── */
#define TEST_SAMPLES    256
#define TEST_AUDIO      (TEST_SAMPLES / AUDIO_DECIM)     /* 32 */

/* ── Filter Coefficients (identical to fm_radio.h) ── */

static const int IIR_COEFF_TAPS = 2;
static const int IIR_Y_COEFFS[] = {QUANTIZE_F(0.0f), QUANTIZE_F((W_PP - 1.0f) / (W_PP + 1.0f))};
static const int IIR_X_COEFFS[] = {QUANTIZE_F(W_PP / (1.0f + W_PP)), QUANTIZE_F(W_PP / (1.0f + W_PP))};

static const int CHANNEL_COEFF_TAPS = 20;
static const int CHANNEL_COEFFS_REAL[] = {
    0x00000001, 0x00000008, 0xfffffff3, 0x00000009, 0x0000000b, 0xffffffd3, 0x00000045, 0xffffffd3,
    0xffffffb1, 0x00000257, 0x00000257, 0xffffffb1, 0xffffffd3, 0x00000045, 0xffffffd3, 0x0000000b,
    0x00000009, 0xfffffff3, 0x00000008, 0x00000001
};
static const int CHANNEL_COEFFS_IMAG[] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

static const int AUDIO_LPR_COEFF_TAPS = 32;
static const int AUDIO_LPR_COEFFS[] = {
    0xfffffffd, 0xfffffffa, 0xfffffff4, 0xffffffed, 0xffffffe5, 0xffffffdf, 0xffffffe2, 0xfffffff3,
    0x00000015, 0x0000004e, 0x0000009b, 0x000000f9, 0x0000015d, 0x000001be, 0x0000020e, 0x00000243,
    0x00000243, 0x0000020e, 0x000001be, 0x0000015d, 0x000000f9, 0x0000009b, 0x0000004e, 0x00000015,
    0xfffffff3, 0xffffffe2, 0xffffffdf, 0xffffffe5, 0xffffffed, 0xfffffff4, 0xfffffffa, 0xfffffffd
};

static const int AUDIO_LMR_COEFF_TAPS = 32;
static const int AUDIO_LMR_COEFFS[] = {
    0xfffffffd, 0xfffffffa, 0xfffffff4, 0xffffffed, 0xffffffe5, 0xffffffdf, 0xffffffe2, 0xfffffff3,
    0x00000015, 0x0000004e, 0x0000009b, 0x000000f9, 0x0000015d, 0x000001be, 0x0000020e, 0x00000243,
    0x00000243, 0x0000020e, 0x000001be, 0x0000015d, 0x000000f9, 0x0000009b, 0x0000004e, 0x00000015,
    0xfffffff3, 0xffffffe2, 0xffffffdf, 0xffffffe5, 0xffffffed, 0xfffffff4, 0xfffffffa, 0xfffffffd
};

static const int BP_PILOT_COEFF_TAPS = 32;
static const int BP_PILOT_COEFFS[] = {
    0x0000000e, 0x0000001f, 0x00000034, 0x00000048, 0x0000004e, 0x00000036, 0xfffffff8, 0xffffff98,
    0xffffff2d, 0xfffffeda, 0xfffffec3, 0xfffffefe, 0xffffff8a, 0x0000004a, 0x0000010f, 0x000001a1,
    0x000001a1, 0x0000010f, 0x0000004a, 0xffffff8a, 0xfffffefe, 0xfffffec3, 0xfffffeda, 0xffffff2d,
    0xffffff98, 0xfffffff8, 0x00000036, 0x0000004e, 0x00000048, 0x00000034, 0x0000001f, 0x0000000e
};

static const int BP_LMR_COEFF_TAPS = 32;
static const int BP_LMR_COEFFS[] = {
    0x00000000, 0x00000000, 0xfffffffc, 0xfffffff9, 0xfffffffe, 0x00000008, 0x0000000c, 0x00000002,
    0x00000003, 0x0000001e, 0x00000030, 0xfffffffc, 0xffffff8c, 0xffffff58, 0xffffffc3, 0x0000008a,
    0x0000008a, 0xffffffc3, 0xffffff58, 0xffffff8c, 0xfffffffc, 0x00000030, 0x0000001e, 0x00000003,
    0x00000002, 0x0000000c, 0x00000008, 0xfffffffe, 0xfffffff9, 0xfffffffc, 0x00000000, 0x00000000
};

static const int HP_COEFF_TAPS = 32;
static const int HP_COEFFS[] = {
    0xffffffff, 0x00000000, 0x00000000, 0x00000002, 0x00000004, 0x00000008, 0x0000000b, 0x0000000c,
    0x00000008, 0xffffffff, 0xffffffee, 0xffffffd7, 0xffffffbb, 0xffffff9f, 0xffffff87, 0xffffff76,
    0xffffff76, 0xffffff87, 0xffffff9f, 0xffffffbb, 0xffffffd7, 0xffffffee, 0xffffffff, 0x00000008,
    0x0000000c, 0x0000000b, 0x00000008, 0x00000004, 0x00000002, 0x00000000, 0x00000000, 0xffffffff
};

/* ── Helper: dump array to file ── */
static void dump_int_array(const char *filename, const int *arr, int n)
{
    FILE *f = fopen(filename, "w");
    if (!f) { printf("ERROR: cannot open %s\n", filename); return; }
    for (int i = 0; i < n; i++)
        fprintf(f, "%d\n", arr[i]);
    fclose(f);
    printf("  wrote %s (%d values)\n", filename, n);
}

/* ── DSP Functions (identical to fm_radio.cpp) ── */

void read_IQ(unsigned char *IQ, int *I, int *Q, int samples)
{
    for (int i = 0; i < samples; i++) {
        I[i] = QUANTIZE_I((short)(IQ[i*4+1] << 8) | (short)IQ[i*4+0]);
        Q[i] = QUANTIZE_I((short)(IQ[i*4+3] << 8) | (short)IQ[i*4+2]);
    }
}

int qarctan(int y, int x)
{
    const int quad1 = QUANTIZE_F(PI / 4.0);
    const int quad3 = QUANTIZE_F(3.0 * PI / 4.0);
    int abs_y = abs(y) + 1;
    int angle = 0;
    int r = 0;

    if (x >= 0) {
        r = QUANTIZE_I(x - abs_y) / (x + abs_y);
        angle = quad1 - DEQUANTIZE(quad1 * r);
    } else {
        r = QUANTIZE_I(x + abs_y) / (abs_y - x);
        angle = quad3 - DEQUANTIZE(quad1 * r);
    }
    return ((y < 0) ? -angle : angle);
}

void demodulate(int real, int imag, int *real_prev, int *imag_prev, const int gain, int *demod_out)
{
    int r = DEQUANTIZE(*real_prev * real) - DEQUANTIZE(-*imag_prev * imag);
    int i = DEQUANTIZE(*real_prev * imag) + DEQUANTIZE(-*imag_prev * real);
    *demod_out = DEQUANTIZE(gain * qarctan(i, r));
    *real_prev = real;
    *imag_prev = imag;
}

void demodulate_n(int *real, int *imag, int *real_prev, int *imag_prev, const int n_samples, const int gain, int *demod_out)
{
    for (int i = 0; i < n_samples; i++)
        demodulate(real[i], imag[i], real_prev, imag_prev, gain, &demod_out[i]);
}

void fir(int *x_in, const int *coeff, int *x, const int taps, const int decimation, int *y_out)
{
    int y = 0;
    for (int j = taps-1; j > decimation-1; j--)
        x[j] = x[j-decimation];
    for (int i = 0; i < decimation; i++)
        x[decimation-i-1] = x_in[i];
    for (int j = 0; j < taps; j++)
        y += DEQUANTIZE(coeff[taps-j-1] * x[j]);
    *y_out = y;
}

void fir_n(int *x_in, const int n_samples, const int *coeff, int *x, const int taps, const int decimation, int *y_out)
{
    int j = 0;
    int n_elements = n_samples / decimation;
    for (int i = 0; i < n_elements; i++, j += decimation)
        fir(&x_in[j], coeff, x, taps, decimation, &y_out[i]);
}

void fir_cmplx(int *x_real_in, int *x_imag_in, const int *h_real, const int *h_imag,
               int *x_real, int *x_imag, const int taps, const int decimation,
               int *y_real_out, int *y_imag_out)
{
    int y_real = 0, y_imag = 0;
    for (int j = taps-1; j > decimation-1; j--) {
        x_real[j] = x_real[j-decimation];
        x_imag[j] = x_imag[j-decimation];
    }
    for (int i = 0; i < decimation; i++) {
        x_real[decimation-i-1] = x_real_in[i];
        x_imag[decimation-i-1] = x_imag_in[i];
    }
    for (int i = 0; i < taps; i++) {
        y_real += DEQUANTIZE((h_real[i] * x_real[i]) - (h_imag[i] * x_imag[i]));
        y_imag += DEQUANTIZE((h_real[i] * x_imag[i]) - (h_imag[i] * x_real[i]));
    }
    *y_real_out = y_real;
    *y_imag_out = y_imag;
}

void fir_cmplx_n(int *x_real_in, int *x_imag_in, const int n_samples, const int *h_real, const int *h_imag,
                 int *x_real, int *x_imag, const int taps, const int decimation,
                 int *y_real_out, int *y_imag_out)
{
    int j = 0;
    int n_elements = n_samples / decimation;
    for (int i = 0; i < n_elements; i++, j += decimation)
        fir_cmplx(&x_real_in[j], &x_imag_in[j], h_real, h_imag, x_real, x_imag, taps, decimation, &y_real_out[i], &y_imag_out[i]);
}

void multiply_n(int *x_in, int *y_in, const int n_samples, int *output)
{
    for (int i = 0; i < n_samples; i++)
        output[i] = DEQUANTIZE(x_in[i] * y_in[i]);
}

void add_n(int *x_in, int *y_in, const int n_samples, int *output)
{
    for (int i = 0; i < n_samples; i++)
        output[i] = x_in[i] + y_in[i];
}

void sub_n(int *x_in, int *y_in, const int n_samples, int *output)
{
    for (int i = 0; i < n_samples; i++)
        output[i] = x_in[i] - y_in[i];
}

void iir(int *x_in, const int *x_coeffs, const int *y_coeffs, int *x, int *y, const int taps, const int decimation, int *y_out)
{
    int y1 = 0, y2 = 0;
    for (int j = taps-1; j > decimation-1; j--)
        x[j] = x[j-decimation];
    for (int i = 0; i < decimation; i++)
        x[decimation-i-1] = x_in[i];
    for (int j = taps-1; j > 0; j--)
        y[j] = y[j-1];
    for (int i = 0; i < taps; i++) {
        y1 += DEQUANTIZE(x_coeffs[i] * x[i]);
        y2 += DEQUANTIZE(y_coeffs[i] * y[i]);
    }
    y[0] = y1 + y2;
    *y_out = y[taps-1];
}

void iir_n(int *x_in, const int n_samples, const int *x_coeffs, const int *y_coeffs, int *x, int *y, const int taps, int decimation, int *y_out)
{
    int j = 0;
    int n_elements = n_samples / decimation;
    for (int i = 0; i < n_elements; i++, j += decimation)
        iir(&x_in[j], x_coeffs, y_coeffs, x, y, taps, decimation, &y_out[i]);
}

void gain_n(int *input, const int n_samples, int gain, int *output)
{
    for (int i = 0; i < n_samples; i++)
        output[i] = DEQUANTIZE(input[i] * gain) << (14-BITS);
}

/* ── Main: run signal chain and dump all intermediate results ── */

int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Usage: %s <usrp_subset.dat>\n", argv[0]);
        printf("Create subset: dd if=usrp.dat of=usrp_subset.dat bs=1 count=%d\n", TEST_SAMPLES*4);
        return -1;
    }

    /* Read input file */
    unsigned char IQ_raw[TEST_SAMPLES * 4];
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { printf("Cannot open %s\n", argv[1]); return -1; }
    int bytes_read = fread(IQ_raw, 1, TEST_SAMPLES * 4, fp);
    fclose(fp);
    printf("Read %d bytes (%d IQ samples)\n", bytes_read, bytes_read/4);

    int actual_samples = bytes_read / 4;

    /* ── Signal chain arrays ── */
    int I[TEST_SAMPLES], Q[TEST_SAMPLES];
    int I_fir[TEST_SAMPLES], Q_fir[TEST_SAMPLES];
    int demod[TEST_SAMPLES];
    int audio_lpr[TEST_AUDIO];
    int bp_lmr[TEST_SAMPLES];
    int bp_pilot[TEST_SAMPLES];
    int hp_pilot[TEST_SAMPLES];
    int audio_lmr[TEST_AUDIO];
    int square[TEST_SAMPLES];
    int multiply[TEST_SAMPLES];
    int left[TEST_AUDIO], right[TEST_AUDIO];
    int left_deemph[TEST_AUDIO], right_deemph[TEST_AUDIO];
    int left_audio[TEST_AUDIO], right_audio[TEST_AUDIO];

    /* ── State arrays (static in original, zero-init here) ── */
    int fir_cmplx_x_real[MAX_TAPS] = {0};
    int fir_cmplx_x_imag[MAX_TAPS] = {0};
    int demod_real_prev = 0, demod_imag_prev = 0;
    int fir_lpr_x[MAX_TAPS] = {0};
    int fir_lmr_x[MAX_TAPS] = {0};
    int fir_bp_x[MAX_TAPS] = {0};
    int fir_pilot_x[MAX_TAPS] = {0};
    int fir_hp_x[MAX_TAPS] = {0};
    int deemph_l_x[MAX_TAPS] = {0}, deemph_l_y[MAX_TAPS] = {0};
    int deemph_r_x[MAX_TAPS] = {0}, deemph_r_y[MAX_TAPS] = {0};

    /* Initialize arrays to zero */
    memset(I, 0, sizeof(I));
    memset(Q, 0, sizeof(Q));
    memset(I_fir, 0, sizeof(I_fir));
    memset(Q_fir, 0, sizeof(Q_fir));
    memset(demod, 0, sizeof(demod));

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 1: Read IQ                                   */
    /* ═══════════════════════════════════════════════════ */
    printf("\n[1] read_IQ\n");
    read_IQ(IQ_raw, I, Q, actual_samples);
    dump_int_array("01_iq_raw_i.txt", I, actual_samples);
    dump_int_array("01_iq_raw_q.txt", Q, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 2: Channel LPF (complex FIR, 20 taps)       */
    /* ═══════════════════════════════════════════════════ */
    printf("[2] fir_cmplx (channel LPF)\n");
    fir_cmplx_n(I, Q, actual_samples, CHANNEL_COEFFS_REAL, CHANNEL_COEFFS_IMAG,
                fir_cmplx_x_real, fir_cmplx_x_imag, CHANNEL_COEFF_TAPS, 1, I_fir, Q_fir);
    dump_int_array("02_channel_lpf_i.txt", I_fir, actual_samples);
    dump_int_array("02_channel_lpf_q.txt", Q_fir, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 3: FM Demodulate                             */
    /* ═══════════════════════════════════════════════════ */
    printf("[3] demodulate\n");
    demodulate_n(I_fir, Q_fir, &demod_real_prev, &demod_imag_prev, actual_samples, FM_DEMOD_GAIN, demod);
    dump_int_array("03_demod.txt", demod, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 4: L+R LPF (32 taps, decim=8)               */
    /* ═══════════════════════════════════════════════════ */
    printf("[4] L+R LPF (audio_lpr)\n");
    int audio_n = actual_samples / AUDIO_DECIM;
    fir_n(demod, actual_samples, AUDIO_LPR_COEFFS, fir_lpr_x, AUDIO_LPR_COEFF_TAPS, AUDIO_DECIM, audio_lpr);
    dump_int_array("04_audio_lpr.txt", audio_lpr, audio_n);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 5: L-R BPF (32 taps, no decim)              */
    /* ═══════════════════════════════════════════════════ */
    printf("[5] L-R BPF\n");
    fir_n(demod, actual_samples, BP_LMR_COEFFS, fir_bp_x, BP_LMR_COEFF_TAPS, 1, bp_lmr);
    dump_int_array("05_bp_lmr.txt", bp_lmr, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 6: Pilot BPF (32 taps, no decim)            */
    /* ═══════════════════════════════════════════════════ */
    printf("[6] Pilot BPF\n");
    fir_n(demod, actual_samples, BP_PILOT_COEFFS, fir_pilot_x, BP_PILOT_COEFF_TAPS, 1, bp_pilot);
    dump_int_array("06_bp_pilot.txt", bp_pilot, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 7: Square pilot                              */
    /* ═══════════════════════════════════════════════════ */
    printf("[7] Square pilot\n");
    multiply_n(bp_pilot, bp_pilot, actual_samples, square);
    dump_int_array("07_square.txt", square, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 8: HP filter (remove DC from squared pilot)  */
    /* ═══════════════════════════════════════════════════ */
    printf("[8] HP filter\n");
    fir_n(square, actual_samples, HP_COEFFS, fir_hp_x, HP_COEFF_TAPS, 1, hp_pilot);
    dump_int_array("08_hp_pilot.txt", hp_pilot, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 9: Multiply HP pilot × L-R BPF              */
    /* ═══════════════════════════════════════════════════ */
    printf("[9] Multiply (demod L-R)\n");
    multiply_n(hp_pilot, bp_lmr, actual_samples, multiply);
    dump_int_array("09_multiply.txt", multiply, actual_samples);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 10: L-R LPF (32 taps, decim=8)              */
    /* ═══════════════════════════════════════════════════ */
    printf("[10] L-R LPF (audio_lmr)\n");
    fir_n(multiply, actual_samples, AUDIO_LMR_COEFFS, fir_lmr_x, AUDIO_LMR_COEFF_TAPS, AUDIO_DECIM, audio_lmr);
    dump_int_array("10_audio_lmr.txt", audio_lmr, audio_n);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 11: L = (L+R) + (L-R), R = (L+R) - (L-R)   */
    /* ═══════════════════════════════════════════════════ */
    printf("[11] Add/Sub (L/R separation)\n");
    add_n(audio_lpr, audio_lmr, audio_n, left);
    sub_n(audio_lpr, audio_lmr, audio_n, right);
    dump_int_array("11_left_raw.txt", left, audio_n);
    dump_int_array("11_right_raw.txt", right, audio_n);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 12: Deemphasis IIR                           */
    /* ═══════════════════════════════════════════════════ */
    printf("[12] Deemphasis\n");
    iir_n(left, audio_n, IIR_X_COEFFS, IIR_Y_COEFFS, deemph_l_x, deemph_l_y, IIR_COEFF_TAPS, 1, left_deemph);
    iir_n(right, audio_n, IIR_X_COEFFS, IIR_Y_COEFFS, deemph_r_x, deemph_r_y, IIR_COEFF_TAPS, 1, right_deemph);
    dump_int_array("12_left_deemph.txt", left_deemph, audio_n);
    dump_int_array("12_right_deemph.txt", right_deemph, audio_n);

    /* ═══════════════════════════════════════════════════ */
    /*  STEP 13: Volume / Gain                            */
    /* ═══════════════════════════════════════════════════ */
    printf("[13] Gain (volume)\n");
    gain_n(left_deemph, audio_n, VOLUME_LEVEL, left_audio);
    gain_n(right_deemph, audio_n, VOLUME_LEVEL, right_audio);
    dump_int_array("13_left_audio.txt", left_audio, audio_n);
    dump_int_array("13_right_audio.txt", right_audio, audio_n);

    printf("\nDone! Generated test vectors for %d IQ samples → %d audio samples\n", actual_samples, audio_n);
    return 0;
}
