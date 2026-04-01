import uvm_pkg::*;

class my_uvm_transaction extends uvm_sequence_item;
    logic [7:0] iq_byte;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(iq_byte, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_file, i;
        logic [7:0] byte_val;

        `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", IQ_FILE_NAME), UVM_LOW);

        in_file = $fopen(IQ_FILE_NAME, "rb");
        if (!in_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", IQ_FILE_NAME));
        end

        for (i = 0; i < NUM_IQ_BYTES; i++) begin
            tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
            start_item(tx);
            tx.iq_byte = $fgetc(in_file);
            finish_item(tx);
        end

        `uvm_info("SEQ_RUN", $sformatf("Sent %0d bytes from %s", NUM_IQ_BYTES, IQ_FILE_NAME), UVM_LOW);
        $fclose(in_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
