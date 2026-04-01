import uvm_pkg::*;
import my_uvm_package::*;
import fm_radio_pkg::*;

`include "my_uvm_if.sv"

`timescale 1ns/1ps

module my_uvm_tb;

    my_uvm_if vif();

    fm_radio_top dut (
        .clk             (vif.clock),
        .rst             (vif.reset),
        .iq_byte_in      (vif.iq_byte),
        .iq_byte_valid   (vif.iq_byte_valid),
        .left_audio_out  (vif.left_audio),
        .right_audio_out (vif.right_audio),
        .audio_valid     (vif.audio_valid)
    );

    initial begin
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));
        run_test("my_uvm_test");
    end

    // Reset
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        vif.iq_byte <= 8'b0;
        vif.iq_byte_valid <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 100 MHz clock
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;

endmodule
