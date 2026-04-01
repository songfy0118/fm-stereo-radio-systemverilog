# fm_radio_wave.do - Waveform configuration

onerror {resume}

add wave -noupdate -divider {Clock/Reset}
add wave -noupdate /fm_radio_tb/clk
add wave -noupdate /fm_radio_tb/rst

add wave -noupdate -divider {IQ Input}
add wave -noupdate /fm_radio_tb/iq_byte
add wave -noupdate /fm_radio_tb/iq_byte_valid

add wave -noupdate -divider {read_iq}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/iq_i
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/iq_q
add wave -noupdate /fm_radio_tb/dut/iq_valid

add wave -noupdate -divider {Channel LPF}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/ch_i
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/ch_q
add wave -noupdate /fm_radio_tb/dut/ch_valid

add wave -noupdate -divider {Demod}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/demod
add wave -noupdate /fm_radio_tb/dut/demod_valid

add wave -noupdate -divider {Audio L+R}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/audio_lpr
add wave -noupdate /fm_radio_tb/dut/lpr_valid

add wave -noupdate -divider {Audio L-R}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/dut/audio_lmr
add wave -noupdate /fm_radio_tb/dut/lmr_valid

add wave -noupdate -divider {Audio Output}
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/left_out
add wave -noupdate -format Analog-Step -height 50 /fm_radio_tb/right_out
add wave -noupdate /fm_radio_tb/audio_valid

add wave -noupdate -divider {Counters}
add wave -noupdate /fm_radio_tb/audio_cnt
add wave -noupdate /fm_radio_tb/errors
add wave -noupdate /fm_radio_tb/matches

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
WaveRestoreZoom {0 ns} {50000 ns}
