import uvm_pkg::*;

interface my_uvm_if;
    logic        clock;
    logic        reset;
    logic [7:0]  iq_byte;
    logic        iq_byte_valid;
    logic signed [31:0] left_audio;
    logic signed [31:0] right_audio;
    logic        audio_valid;
endinterface
