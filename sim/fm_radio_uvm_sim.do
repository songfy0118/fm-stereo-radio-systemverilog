if {[file exists work]} { vdel -all -lib work }
vlib work

vlog -sv ../rtl/fm_radio_pkg.sv
vlog -sv ../rtl/read_iq.sv
vlog -sv ../rtl/fir.sv
vlog -sv ../rtl/fir_cmplx.sv
vlog -sv ../rtl/div.sv
vlog -sv ../rtl/qarctan.sv
vlog -sv ../rtl/demodulate.sv
vlog -sv ../rtl/iir.sv
vlog -sv ../rtl/arith.sv
vlog -sv ../rtl/fifo.sv
vlog -sv ../rtl/fm_radio_top.sv

vlog -sv +incdir+../uvm ../uvm/my_uvm_pkg.sv
vlog -sv +incdir+../uvm ../uvm/my_uvm_tb.sv

vsim -voptargs="+acc" work.my_uvm_tb

do fm_radio_uvm_wave.do

run -all
quit -f
