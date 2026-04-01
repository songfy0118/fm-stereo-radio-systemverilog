# fm_radio_uvm_wave.do - UVM Waveform configuration
onerror {resume}

add wave -noupdate -divider {Clock/Reset}
add wave -noupdate -radix binary /my_uvm_tb/vif/clock
add wave -noupdate -radix binary /my_uvm_tb/vif/reset

add wave -noupdate -divider {IQ Input}
add wave -noupdate -radix hex /my_uvm_tb/vif/iq_byte
add wave -noupdate -radix binary /my_uvm_tb/vif/iq_byte_valid

add wave -noupdate -divider {read_iq}
add wave -noupdate -radix hex /my_uvm_tb/dut/iq_i
add wave -noupdate -radix hex /my_uvm_tb/dut/iq_q
add wave -noupdate -radix binary /my_uvm_tb/dut/iq_valid

add wave -noupdate -divider {Channel LPF}
add wave -noupdate -radix hex /my_uvm_tb/dut/ch_i
add wave -noupdate -radix hex /my_uvm_tb/dut/ch_q
add wave -noupdate -radix binary /my_uvm_tb/dut/ch_valid

add wave -noupdate -divider {Demod}
add wave -noupdate -radix hex /my_uvm_tb/dut/demod_data
add wave -noupdate -radix binary /my_uvm_tb/dut/demod_valid

add wave -noupdate -divider {Audio L+R}
add wave -noupdate -radix hex /my_uvm_tb/dut/audio_lpr
add wave -noupdate -radix binary /my_uvm_tb/dut/lpr_valid

add wave -noupdate -divider {Audio L-R}
add wave -noupdate -radix hex /my_uvm_tb/dut/audio_lmr
add wave -noupdate -radix binary /my_uvm_tb/dut/lmr_valid

add wave -noupdate -divider {Audio Output}
add wave -noupdate -radix hex /my_uvm_tb/vif/left_audio
add wave -noupdate -radix hex /my_uvm_tb/vif/right_audio
add wave -noupdate -radix binary /my_uvm_tb/vif/audio_valid

WaveRestoreCursors {{Cursor 1} {0 ns} 0}
WaveRestoreZoom {0 ns} {50000 ns}
