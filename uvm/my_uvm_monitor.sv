import uvm_pkg::*;

// Transaction for audio output (carries both L and R)
class my_uvm_audio_transaction extends uvm_sequence_item;
    logic signed [31:0] left_audio;
    logic signed [31:0] right_audio;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_audio_transaction)
        `uvm_field_int(left_audio, UVM_ALL_ON)
        `uvm_field_int(right_audio, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_audio_transaction


// Monitor: captures DUT audio output
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_audio_transaction) mon_ap_output;
    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_audio_transaction tx_out;

        @(posedge vif.reset)
        @(negedge vif.reset)

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.audio_valid) begin
                    tx_out = my_uvm_audio_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));
                    tx_out.left_audio = vif.left_audio;
                    tx_out.right_audio = vif.right_audio;
                    mon_ap_output.write(tx_out);
                end
            end
        end
    endtask: run_phase
endclass: my_uvm_monitor_output


// Monitor: reads golden reference files and sends to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_audio_transaction) mon_ap_compare;
    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int left_file, right_file, i;
        int left_val, right_val;
        my_uvm_audio_transaction tx_cmp;

        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 20));
        phase.raise_objection(.obj(this));

        @(posedge vif.reset)
        @(negedge vif.reset)

        left_file = $fopen(LEFT_CMP_NAME, "r");
        right_file = $fopen(RIGHT_CMP_NAME, "r");
        if (!left_file || !right_file) begin
            `uvm_fatal("MON_CMP", "Failed to open golden reference files");
        end

        // Read golden values synchronized with DUT output
        i = 0;
        while (i < NUM_AUDIO_SAMPLES) begin
            @(negedge vif.clock)
            begin
                if (vif.audio_valid) begin
                    void'($fscanf(left_file, "%d", left_val));
                    void'($fscanf(right_file, "%d", right_val));
                    tx_cmp = my_uvm_audio_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));
                    tx_cmp.left_audio = left_val;
                    tx_cmp.right_audio = right_val;
                    mon_ap_compare.write(tx_cmp);
                    i++;
                end
            end
        end

        $fclose(left_file);
        $fclose(right_file);
        phase.drop_objection(.obj(this));
    endtask: run_phase
endclass: my_uvm_monitor_compare
