import uvm_pkg::*;

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(my_uvm_audio_transaction) sb_export_output;
    uvm_analysis_export #(my_uvm_audio_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(my_uvm_audio_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(my_uvm_audio_transaction) compare_fifo;

    my_uvm_audio_transaction tx_out;
    my_uvm_audio_transaction tx_cmp;

    int match_cnt = 0;
    int error_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out = new("tx_out");
        tx_cmp = new("tx_cmp");
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_export_output  = new("sb_export_output", this);
        sb_export_compare = new("sb_export_compare", this);
        output_fifo  = new("output_fifo", this);
        compare_fifo = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run

    virtual function void comparison();
        if (tx_out.left_audio == tx_cmp.left_audio &&
            tx_out.right_audio == tx_cmp.right_audio) begin
            match_cnt++;
            `uvm_info("SB_CMP", $sformatf("MATCH [%0d] L=%0d R=%0d",
                match_cnt-1, tx_out.left_audio, tx_out.right_audio), UVM_LOW);
        end else begin
            error_cnt++;
            `uvm_error("SB_CMP", $sformatf("MISMATCH [%0d] Got L=%0d R=%0d, Exp L=%0d R=%0d",
                match_cnt + error_cnt - 1,
                tx_out.left_audio, tx_out.right_audio,
                tx_cmp.left_audio, tx_cmp.right_audio));
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SB_REPORT", $sformatf("\n========================================\n  FM Radio UVM Results\n  Matches: %0d / %0d\n  Errors:  %0d\n========================================",
            match_cnt, NUM_AUDIO_SAMPLES, error_cnt), UVM_LOW);
        if (error_cnt == 0 && match_cnt == NUM_AUDIO_SAMPLES)
            `uvm_info("SB_REPORT", "*** TEST PASSED ***", UVM_LOW)
        else
            `uvm_error("SB_REPORT", "*** TEST FAILED ***");
    endfunction: report_phase
endclass: my_uvm_scoreboard
