# FM Stereo Radio Receiver — SystemVerilog RTL

Northwestern University — COMP_ENG 355: ASIC and FPGA Design

Final Project — Feiyang Song & Lincy Lin (Team 8)

## Overview

A fully synthesizable FM stereo radio receiver implemented in SystemVerilog. The design takes raw 8-bit IQ samples from a USRP software-defined radio capture and produces stereo (left/right) 32-bit audio output through a complete DSP processing chain. All arithmetic uses 10-bit fixed-point (Q21.10) with a quantization value of 1024.

## Directory Structure

    fm_radio/
    ├── rtl/                    Synthesizable SystemVerilog design (11 files)
    │   ├── fm_radio_pkg.sv     Package: constants, coefficients, dequantize function
    │   ├── fm_radio_top.sv     Top-level module wiring all pipeline stages
    │   ├── read_iq.sv          Deserialise 4 bytes into signed 32-bit I/Q pair
    │   ├── fir_cmplx.sv        20-tap complex channel low-pass filter (0-80 kHz)
    │   ├── demodulate.sv       3-cycle FM demodulator (conjugate multiply + qarctan + gain)
    │   ├── qarctan.sv          Piecewise atan2 approximation with restoring divider
    │   ├── div.sv              Parameterised restoring division (no / operator)
    │   ├── fir.sv              Parameterised FIR filter (32 taps, configurable decimation)
    │   ├── iir.sv              2-tap IIR de-emphasis filter (75 us time constant)
    │   ├── arith.sv            Arithmetic modules: multiply, add, sub, gain
    │   └── fifo.sv             Synchronous FIFO for parallel path alignment
    │
    ├── uvm/                    UVM verification environment (14 files)
    │   ├── my_uvm_pkg.sv       Package including all UVM files in dependency order
    │   ├── my_uvm_tb.sv        Top-level: instantiates DUT + interface, clock/reset
    │   ├── my_uvm_if.sv        Virtual interface with IQ input and stereo audio output
    │   ├── my_uvm_test.sv      Top-level test: builds env, starts sequence
    │   ├── my_uvm_env.sv       Instantiates agent and scoreboard
    │   ├── my_uvm_agent.sv     Connects sequencer, driver, and monitors
    │   ├── my_uvm_driver.sv    Drives IQ bytes into DUT one byte per clock cycle
    │   ├── my_uvm_sequence.sv  Reads binary usrp_subset.dat, sends byte transactions
    │   ├── my_uvm_monitor_output.sv    Captures DUT left/right audio output
    │   ├── my_uvm_monitor_compare.sv   Reads expected audio from reference files
    │   ├── my_uvm_scoreboard.sv        Compares output vs expected, reports matches/errors
    │   ├── my_uvm_monitor.sv   Base monitor class
    │   ├── my_uvm_config.sv    Configuration object
    │   └── my_uvm_globals.sv   Constants: file paths, NUM_IQ_SAMPLES=256, clock period
    │
    ├── sim/                    UVM simulation directory
    │   ├── run_simulation      Entry point script (run from this directory)
    │   ├── fm_radio_uvm_sim.do QuestaSim .do file with wave loading
    │   ├── fm_radio_uvm_wave.do Waveform configuration (hex values, dividers)
    │   ├── usrp_subset.dat     Binary IQ input data (256 samples = 1024 bytes)
    │   ├── 13_left_audio.txt   Expected left channel output (32 samples)
    │   └── 13_right_audio.txt  Expected right channel output (32 samples)
    │
    ├── tb/                     Standalone testbench (non-UVM)
    │   ├── fm_radio_tb.sv      Self-checking testbench with file I/O
    │   ├── fm_radio_sim.do     QuestaSim .do file
    │   ├── fm_radio_wave.do    Waveform configuration with analog display
    │   ├── usrp_subset.dat     Binary IQ input data
    │   ├── 13_left_audio.txt   Expected left channel output
    │   └── 13_right_audio.txt  Expected right channel output
    │
    ├── sw_ref/                 C reference implementation
    │   ├── fm_radio_test.c     C model that generates all intermediate reference files
    │   ├── Makefile            Build with: make
    │   ├── usrp_subset.dat     Binary IQ input data
    │   ├── 13_left_audio.txt   Final left audio reference output
    │   └── 13_right_audio.txt  Final right audio reference output
    │
    └── syn/                    Synthesis project files
        ├── FM_Radio.prj        Synplify Pro project (Virtex UltraScale+ XCVU13P)
        └── fm_radio.sdc        Timing constraint: 10 MHz clock

## Signal Processing Pipeline

    IQ bytes --> read_iq --> fir_cmplx --> demod --+--> fir(LPR,8x) --> FIFO --> add --> iir --> gain --> Left
                                                  |                             |
                                                  +--> fir(pilot) --> square --> fir(HP) --+
                                                  |                                       |
                                                  +--> fir(LMR BPF) --> FIFO --> mult ----+
                                                  |                                       |
                                                  |                  fir(LMR LPF,8x) <---+
                                                  |                             |
                                                  +-----------------------------+--> sub --> iir --> gain --> Right

Key design decisions:
- Streaming pipeline with in_valid/out_valid handshaking, no global FSM
- Combinational MAC (all 32 taps computed in one cycle via always_comb)
- Two 64-entry FIFOs to synchronize parallel paths with different latencies
- Restoring division in qarctan (no / operator used anywhere)
- All filter coefficients defined as localparams in fm_radio_pkg.sv

## Running UVM Simulation

    cd fm_radio/sim/
    ./run_simulation

The run_simulation script performs these 8 steps:
1. Sources the QuestaSim environment (/vol/eecs392/env/questasim.env)
2. Creates the work library (vlib work)
3. Compiles all 11 SystemVerilog RTL files
4. Compiles UVM package and testbench files
5. Launches QuestaSim and loads waveform signals (hex values with dividers)
6. Runs simulation to completion
7. Scoreboard compares all 32 output audio pairs against C reference
8. Reports total matches, errors, and PASS/FAIL status

Expected output:

    FM Radio UVM Results
    Matches: 32 / 32
    Errors:  0
    *** TEST PASSED ***

## Running Standalone Testbench

    cd fm_radio/tb/
    source /vol/eecs392/env/questasim.env
    vsim -c -do fm_radio_sim.do

Expected output:

    FM Radio Testbench Results
    Matches: 32 / 32
    Errors:  0
    *** TEST PASSED ***

## Synthesis

Open fm_radio/syn/FM_Radio.prj in Synplify Pro. The project targets:
- Device: Xilinx Virtex UltraScale+ XCVU13P, FSGA2577, -1 speed grade
- Clock constraint: 10 MHz (defined in fm_radio.sdc)
- All RTL source paths use relative paths (../rtl/)

Results:
- Estimated frequency: 13.3 MHz (positive slack of 23.834 ns)
- DSP48 blocks: 460 (parallel MAC across five 32-tap FIR, complex FIR, multipliers, IIR)
- LUTs: 62,574 (qarctan divider, shift registers, valid routing)
- Non-I/O registers: 6,516 (FIR delay lines, pipeline regs, FIFO pointers)
- Block RAMs: 0 (FIFOs use distributed logic)
- Critical path: combinational MAC trees in FIR filters mapped onto DSP48 cascade chains
