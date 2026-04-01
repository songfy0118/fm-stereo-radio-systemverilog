# ============================================================================
# fm_radio_sim.do - ModelSim simulation script (standalone TB)
#
# Run from: tb/ directory
#   vsim -do fm_radio_sim.do
# ============================================================================

# Create work library
if {[file exists work]} { vdel -all -lib work }
vlib work

# Compile RTL
vlog -sv ../rtl/fm_radio_pkg.sv
vlog -sv ../rtl/read_iq.sv
vlog -sv ../rtl/fir.sv
vlog -sv ../rtl/fir_cmplx.sv
vlog -sv ../rtl/qarctan.sv
vlog -sv ../rtl/demodulate.sv
vlog -sv ../rtl/iir.sv
vlog -sv ../rtl/arith.sv
vlog -sv ../rtl/fifo.sv
vlog -sv ../rtl/fm_radio_top.sv

# Compile TB
vlog -sv fm_radio_tb.sv

# Simulate
vsim -voptargs="+acc" work.fm_radio_tb

# Add waves
do fm_radio_wave.do

# Run
run -all
