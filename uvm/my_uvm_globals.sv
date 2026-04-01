`ifndef __GLOBALS__
`define __GLOBALS__

localparam string IQ_FILE_NAME    = "usrp_subset.dat";
localparam string LEFT_CMP_NAME   = "13_left_audio.txt";
localparam string RIGHT_CMP_NAME  = "13_right_audio.txt";
localparam int NUM_IQ_SAMPLES     = 256;
localparam int NUM_IQ_BYTES       = NUM_IQ_SAMPLES * 4;
localparam int NUM_AUDIO_SAMPLES  = 32;
localparam int CLOCK_PERIOD       = 10;

`endif
