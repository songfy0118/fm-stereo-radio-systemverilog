// ============================================================================
// fm_radio_tb - Standalone testbench
//
// Feeds raw IQ bytes to DUT, compares final audio output with golden
// reference from C model (13_left_audio.txt, 13_right_audio.txt).
// ============================================================================
`timescale 1ns/1ps

module fm_radio_tb;
    import fm_radio_pkg::*;

    logic        clk = 0;
    logic        rst;
    logic [7:0]  iq_byte;
    logic        iq_byte_valid;
    logic signed [DW-1:0] left_out, right_out;
    logic        audio_valid;

    always #5 clk = ~clk;  // 100 MHz

    fm_radio_top dut (
        .clk             (clk),
        .rst             (rst),
        .iq_byte_in      (iq_byte),
        .iq_byte_valid   (iq_byte_valid),
        .left_audio_out  (left_out),
        .right_audio_out (right_out),
        .audio_valid     (audio_valid)
    );

    // ── Test parameters ──
    localparam int NUM_IQ     = 256;
    localparam int NUM_BYTES  = NUM_IQ * 4;
    localparam int NUM_AUDIO  = NUM_IQ / AUDIO_DECIM;  // 32

    // ── Data storage ──
    logic [7:0]  raw_bytes [0:NUM_BYTES-1];
    int          golden_left  [0:NUM_AUDIO-1];
    int          golden_right [0:NUM_AUDIO-1];

    int audio_cnt = 0;
    int errors    = 0;
    int match_cnt   = 0;

    // ── Load data from files ──
    initial begin
        int fd, val, i;

        // Load raw IQ bytes
        fd = $fopen("../sw_ref/usrp_subset.dat", "rb");
        if (fd == 0) begin
            $display("ERROR: cannot open usrp_subset.dat");
            $finish;
        end
        for (i = 0; i < NUM_BYTES; i++) begin
            raw_bytes[i] = $fgetc(fd);
        end
        $fclose(fd);

        // Load golden left audio
        fd = $fopen("../sw_ref/13_left_audio.txt", "r");
        if (fd == 0) begin
            $display("ERROR: cannot open 13_left_audio.txt");
            $finish;
        end
        for (i = 0; i < NUM_AUDIO; i++) begin
            void'($fscanf(fd, "%d", golden_left[i]));
        end
        $fclose(fd);

        // Load golden right audio
        fd = $fopen("../sw_ref/13_right_audio.txt", "r");
        if (fd == 0) begin
            $display("ERROR: cannot open 13_right_audio.txt");
            $finish;
        end
        for (i = 0; i < NUM_AUDIO; i++) begin
            void'($fscanf(fd, "%d", golden_right[i]));
        end
        $fclose(fd);

        $display("Loaded %0d IQ bytes, %0d golden audio samples", NUM_BYTES, NUM_AUDIO);
    end

    // ── Monitor audio output ──
    always @(posedge clk) begin
        if (audio_valid && audio_cnt < NUM_AUDIO) begin
            if (left_out == golden_left[audio_cnt] && right_out == golden_right[audio_cnt]) begin
                $display("[%0t] MATCH [%0d] L=%0d R=%0d", $time, audio_cnt, left_out, right_out);
                match_cnt++;
            end else begin
                $display("[%0t] ERROR [%0d] L=%0d (exp %0d) R=%0d (exp %0d)",
                         $time, audio_cnt,
                         left_out, golden_left[audio_cnt],
                         right_out, golden_right[audio_cnt]);
                errors++;
            end
            audio_cnt++;
        end
    end

    // ── Stimulus ──
    initial begin
        rst = 1;
        iq_byte = '0;
        iq_byte_valid = 0;

        repeat (10) @(posedge clk);
        rst = 0;
        repeat (5) @(posedge clk);

        // Feed all bytes
        for (int i = 0; i < NUM_BYTES; i++) begin
            @(posedge clk);
            iq_byte       <= raw_bytes[i];
            iq_byte_valid <= 1'b1;
        end
        @(posedge clk);
        iq_byte_valid <= 1'b0;

        // Wait for pipeline to drain
        repeat (50000) @(posedge clk);

        $display("");
        $display("========================================");
        $display("  FM Radio Testbench Results");
        $display("  Matches: %0d / %0d", match_cnt, NUM_AUDIO);
        $display("  Errors:  %0d", errors);
        $display("========================================");

        if (errors == 0 && match_cnt == NUM_AUDIO)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");

        $finish;
    end

    // Timeout
    initial begin
        #100_000_000;
        $display("TIMEOUT after 100ms sim time");
        $display("Got %0d/%0d audio samples", audio_cnt, NUM_AUDIO);
        $finish;
    end

endmodule
