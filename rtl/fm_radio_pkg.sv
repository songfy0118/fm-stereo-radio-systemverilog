package fm_radio_pkg;
    localparam int BITS      = 10;
    localparam int QUANT_VAL = 1 << BITS;
    localparam int DW        = 32;
    localparam int AUDIO_DECIM = 8;
    localparam int FM_DEMOD_GAIN = 758;
    localparam int VOLUME_LEVEL = 1024;
    localparam int QUAD1 = 804;
    localparam int QUAD3 = 2412;
    localparam int CHANNEL_TAPS   = 20;
    localparam int AUDIO_LPR_TAPS = 32;
    localparam int AUDIO_LMR_TAPS = 32;
    localparam int BP_PILOT_TAPS  = 32;
    localparam int BP_LMR_TAPS    = 32;
    localparam int HP_TAPS        = 32;
    localparam int IIR_TAPS       = 2;

    function automatic logic signed [31:0] dequantize(input logic signed [63:0] val);
        if (val >= 0)
            return 32'(val / 64'(QUANT_VAL));
        else
            return -32'((-val) / 64'(QUANT_VAL));
    endfunction

    localparam logic signed [31:0] CHANNEL_COEFFS [0:19] = '{
        32'sh00000001, 32'sh00000008, 32'shfffffff3, 32'sh00000009,
        32'sh0000000b, 32'shffffffd3, 32'sh00000045, 32'shffffffd3,
        32'shffffffb1, 32'sh00000257, 32'sh00000257, 32'shffffffb1,
        32'shffffffd3, 32'sh00000045, 32'shffffffd3, 32'sh0000000b,
        32'sh00000009, 32'shfffffff3, 32'sh00000008, 32'sh00000001
    };
    localparam logic signed [31:0] AUDIO_LPR_COEFFS [0:31] = '{
        32'shfffffffd, 32'shfffffffa, 32'shfffffff4, 32'shffffffed,
        32'shffffffe5, 32'shffffffdf, 32'shffffffe2, 32'shfffffff3,
        32'sh00000015, 32'sh0000004e, 32'sh0000009b, 32'sh000000f9,
        32'sh0000015d, 32'sh000001be, 32'sh0000020e, 32'sh00000243,
        32'sh00000243, 32'sh0000020e, 32'sh000001be, 32'sh0000015d,
        32'sh000000f9, 32'sh0000009b, 32'sh0000004e, 32'sh00000015,
        32'shfffffff3, 32'shffffffe2, 32'shffffffdf, 32'shffffffe5,
        32'shffffffed, 32'shfffffff4, 32'shfffffffa, 32'shfffffffd
    };
    localparam logic signed [31:0] AUDIO_LMR_COEFFS [0:31] = '{
        32'shfffffffd, 32'shfffffffa, 32'shfffffff4, 32'shffffffed,
        32'shffffffe5, 32'shffffffdf, 32'shffffffe2, 32'shfffffff3,
        32'sh00000015, 32'sh0000004e, 32'sh0000009b, 32'sh000000f9,
        32'sh0000015d, 32'sh000001be, 32'sh0000020e, 32'sh00000243,
        32'sh00000243, 32'sh0000020e, 32'sh000001be, 32'sh0000015d,
        32'sh000000f9, 32'sh0000009b, 32'sh0000004e, 32'sh00000015,
        32'shfffffff3, 32'shffffffe2, 32'shffffffdf, 32'shffffffe5,
        32'shffffffed, 32'shfffffff4, 32'shfffffffa, 32'shfffffffd
    };
    localparam logic signed [31:0] BP_PILOT_COEFFS [0:31] = '{
        32'sh0000000e, 32'sh0000001f, 32'sh00000034, 32'sh00000048,
        32'sh0000004e, 32'sh00000036, 32'shfffffff8, 32'shffffff98,
        32'shffffff2d, 32'shfffffeda, 32'shfffffec3, 32'shfffffefe,
        32'shffffff8a, 32'sh0000004a, 32'sh0000010f, 32'sh000001a1,
        32'sh000001a1, 32'sh0000010f, 32'sh0000004a, 32'shffffff8a,
        32'shfffffefe, 32'shfffffec3, 32'shfffffeda, 32'shffffff2d,
        32'shffffff98, 32'shfffffff8, 32'sh00000036, 32'sh0000004e,
        32'sh00000048, 32'sh00000034, 32'sh0000001f, 32'sh0000000e
    };
    localparam logic signed [31:0] BP_LMR_COEFFS [0:31] = '{
        32'sh00000000, 32'sh00000000, 32'shfffffffc, 32'shfffffff9,
        32'shfffffffe, 32'sh00000008, 32'sh0000000c, 32'sh00000002,
        32'sh00000003, 32'sh0000001e, 32'sh00000030, 32'shfffffffc,
        32'shffffff8c, 32'shffffff58, 32'shffffffc3, 32'sh0000008a,
        32'sh0000008a, 32'shffffffc3, 32'shffffff58, 32'shffffff8c,
        32'shfffffffc, 32'sh00000030, 32'sh0000001e, 32'sh00000003,
        32'sh00000002, 32'sh0000000c, 32'sh00000008, 32'shfffffffe,
        32'shfffffff9, 32'shfffffffc, 32'sh00000000, 32'sh00000000
    };
    localparam logic signed [31:0] HP_COEFFS [0:31] = '{
        32'shffffffff, 32'sh00000000, 32'sh00000000, 32'sh00000002,
        32'sh00000004, 32'sh00000008, 32'sh0000000b, 32'sh0000000c,
        32'sh00000008, 32'shffffffff, 32'shffffffee, 32'shffffffd7,
        32'shffffffbb, 32'shffffff9f, 32'shffffff87, 32'shffffff76,
        32'shffffff76, 32'shffffff87, 32'shffffff9f, 32'shffffffbb,
        32'shffffffd7, 32'shffffffee, 32'shffffffff, 32'sh00000008,
        32'sh0000000c, 32'sh0000000b, 32'sh00000008, 32'sh00000004,
        32'sh00000002, 32'sh00000000, 32'sh00000000, 32'shffffffff
    };
    localparam logic signed [31:0] IIR_X_COEFFS [0:1] = '{32'sd178, 32'sd178};
    localparam logic signed [31:0] IIR_Y_COEFFS [0:1] = '{32'sd0, -32'sd666};
endpackage
