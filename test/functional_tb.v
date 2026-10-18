`timescale 1ns/1ps

// Self-check for the chord generator.
// The chip clock is 2 MHz. This bench counts clocks, not real time.
// Output tones cover 20 Hz to about 15 kHz.
module functional_tb;
    reg        clk;
    reg        rst_n;
    reg        ena;
    reg        sel440;
    reg [12:0] chord_sel;
    reg        drive_sqr;
    reg        hold_high;
    reg [19:0] half_cycles;

    reg        sqr_level;
    integer    sqr_cnt;
    integer    cyc;
    integer    last_avg;
    integer    meas;
    integer    want;
    integer    vi;
    integer    prev;
    integer    guard;
    integer    saw;

    wire [7:0] ui_in  = {chord_sel[6:0], sel440};
    wire [7:0] uio_in = {1'b0, sqr_level, chord_sel[12:7]};
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_chord_synth_lamprotornisunicolor dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (!rst_n) begin
            sqr_cnt   <= 0;
            sqr_level <= 1'b0;
        end else if (hold_high) begin
            sqr_level <= 1'b1;
        end else if (!drive_sqr) begin
            sqr_cnt   <= 0;
            sqr_level <= 1'b0;
        end else if (sqr_cnt >= half_cycles - 1) begin
            sqr_cnt   <= 0;
            sqr_level <= ~sqr_level;
        end else begin
            sqr_cnt <= sqr_cnt + 1;
        end
    end

    // Fixed terminal counts. Same table as chord_gen.
    function integer top_of;
        input integer idx;
        begin
            case (idx)
                0: top_of = 128;
                1: top_of = 121;
                2: top_of = 114;
                3: top_of = 108;
                4: top_of = 102;
                5: top_of = 96;
                6: top_of = 91;
                7: top_of = 85;
                8: top_of = 81;
                9: top_of = 76;
                10: top_of = 72;
                11: top_of = 68;
                default: top_of = 64;
            endcase
        end
    endfunction

    // Average clocks for one cycle of voice idx.
    function integer voice_clocks;
        input integer idx;
        input integer per;
        begin
            voice_clocks = (per * top_of(idx) + 64) / 128;
        end
    endfunction

    task wait_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task do_reset;
        begin
            rst_n = 1'b0;
            wait_cycles(8);
            rst_n = 1'b1;
            wait_cycles(4);
        end
    endtask

    task wait_value_rise;
        integer guard;
        begin
            guard = 0;
            @(posedge clk); #1;
            if (dut.u_chord_gen.value != 0) begin
                while (dut.u_chord_gen.value != 0 && guard < 300000) begin
                    @(posedge clk); #1;
                    guard = guard + 1;
                end
            end
            while (dut.u_chord_gen.value == 0 && guard < 600000) begin
                @(posedge clk); #1;
                guard = guard + 1;
            end
            if (dut.u_chord_gen.value == 0) begin
                $display("FAIL: no rising edge on value");
                $fatal(1);
            end
        end
    endtask

    // Average spacing of nedge rises. Fails when it is not near want.
    task check_period(input integer nedge, input integer want_p, input integer tol);
        integer e;
        integer t0;
        integer acc;
        integer avg;
        integer err;
        begin
            wait_value_rise;
            t0  = cyc;
            acc = 0;
            for (e = 0; e < nedge; e = e + 1) begin
                wait_value_rise;
                acc = acc + (cyc - t0);
                t0  = cyc;
            end
            avg = acc / nedge;
            last_avg = avg;
            err = avg - want_p;
            if (err < 0)
                err = -err;
            $display("  edges %0d  avg %0d  want %0d  tol %0d", nedge, avg, want_p, tol);
            if (err > tol) begin
                $display("FAIL: period error %0d", err);
                $fatal(1);
            end
        end
    endtask

    initial begin
        cyc        = 0;
        rst_n      = 1'b0;
        ena        = 1'b1;
        sel440     = 1'b0;
        chord_sel  = 13'd0;
        drive_sqr  = 1'b0;
        hold_high  = 1'b0;
        half_cycles = 20'd1000;
        sqr_level  = 1'b0;
        sqr_cnt    = 0;

        $display("1. pin map");
        do_reset;
        if (uio_oe !== 8'b0) begin
            $display("FAIL: uio_oe %b", uio_oe);
            $fatal(1);
        end
        if (uio_out !== 8'b0) begin
            $display("FAIL: uio_out %b", uio_out);
            $fatal(1);
        end
        if (uo_out[6:1] !== 6'b0) begin
            $display("FAIL: extra uo bits %b", uo_out);
            $fatal(1);
        end

        $display("2. internal 440 Hz monitor");
        sel440    = 1'b1;
        chord_sel = 13'd0;
        drive_sqr = 1'b0;
        do_reset;
        // sqr_out starts low. Measure one full cycle. 2 * 2273 = 4546.
        guard = 0;
        @(posedge clk); #1;
        while (uo_out[0] !== 1'b1 && guard < 30000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        meas = cyc;
        guard = 0;
        @(posedge clk); #1;
        while (uo_out[0] !== 1'b0 && guard < 30000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        while (uo_out[0] !== 1'b1 && guard < 30000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        meas = cyc - meas;
        $display("  440 full period %0d", meas);
        if (meas != 4546) begin
            $display("FAIL: 440 period");
            $fatal(1);
        end

        $display("3. 1 kHz square, all 13 voices");
        sel440      = 1'b0;
        drive_sqr   = 1'b1;
        half_cycles = 20'd1000; // period 2000 clocks at 2 MHz
        chord_sel   = 13'd1;
        do_reset;
        guard = 0;
        while (dut.u_get_period.valid !== 1'b1 && guard < 20000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        meas = dut.u_get_period.period;
        $display("  measured clocks %0d", meas);
        if (meas < 1990 || meas > 2010) begin
            $display("FAIL: measured period");
            $fatal(1);
        end
        // The divider loads the period on the next measurement.
        wait_cycles(meas + 200);
        prev = 0;
        for (vi = 0; vi < 13; vi = vi + 1) begin
            chord_sel = (13'd1 << vi);
            want = voice_clocks(vi, meas);
            $display("  voice %0d", vi);
            check_period(6, want, 3);
            if (vi > 0 && last_avg > prev) begin
                $display("FAIL: semitone periods are not descending");
                $fatal(1);
            end
            prev = last_avg;
        end

        $display("4. two notes can both be high");
        chord_sel = 13'b0000000000011;
        guard = 0;
        begin : find_two
            saw = 0;
            while (guard < 20000) begin
                @(posedge clk); #1;
                guard = guard + 1;
                if (dut.u_chord_gen.value >= 4'd2)
                    saw = 1;
            end
            if (saw == 0) begin
                $display("FAIL: sum did not reach 2");
                $fatal(1);
            end
        end

        $display("5. chord off keeps PWM low");
        chord_sel = 13'd0;
        // value drops in one clock. The PWM cycle already in progress
        // can finish before the pin stays low.
        wait_cycles(500);
        guard = 0;
        while (guard < 3000) begin
            @(posedge clk); #1;
            guard = guard + 1;
            if (dut.u_chord_gen.value != 0) begin
                $display("FAIL: value active with no chord");
                $fatal(1);
            end
            if (uo_out[7] !== 1'b0) begin
                $display("FAIL: PWM high with no chord");
                $fatal(1);
            end
        end

        $display("6. 15 kHz input, unison and octave");
        half_cycles = 20'd67; // period 134 clocks, about 15 kHz at 2 MHz
        chord_sel   = 13'd1;
        do_reset;
        guard = 0;
        while (dut.u_get_period.valid !== 1'b1 && guard < 10000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        meas = dut.u_get_period.period;
        $display("  measured clocks %0d", meas);
        if (meas < 128 || meas > 140) begin
            $display("FAIL: 15 kHz measure");
            $fatal(1);
        end
        wait_cycles(meas + 200);
        want = voice_clocks(0, meas);
        $display("  unison");
        check_period(8, want, 3);
        chord_sel = 13'h1000;
        want = voice_clocks(12, meas);
        $display("  octave");
        check_period(8, want, 3);

        $display("7. slow band, 100 Hz");
        half_cycles = 20'd10000; // period 20000 clocks
        chord_sel   = 13'd1;
        do_reset;
        guard = 0;
        while (dut.u_get_period.valid !== 1'b1 && guard < 80000) begin
            @(posedge clk); #1;
            guard = guard + 1;
        end
        meas = dut.u_get_period.period;
        $display("  measured clocks %0d", meas);
        if (meas < 19900 || meas > 20100) begin
            $display("FAIL: slow measure");
            $fatal(1);
        end
        wait_cycles(meas + 400);
        want = voice_clocks(0, meas);
        $display("  slow unison");
        check_period(4, want, 3);

        $display("8. input slower than 20 Hz, then recover");
        drive_sqr   = 1'b0;
        hold_high   = 1'b1;
        chord_sel   = 13'd0;
        wait_cycles(100200);
        hold_high   = 1'b0;
        if (dut.u_get_period.state == 2'd1 || dut.u_get_period.state == 2'd2) begin
            $display("FAIL: still counting after 20 Hz");
            $fatal(1);
        end
        drive_sqr   = 1'b1;
        half_cycles = 20'd1000;
        chord_sel   = 13'd1;
        guard = 0;
        meas = 0;
        while (guard < 20000) begin
            @(posedge clk); #1;
            guard = guard + 1;
            if (dut.u_get_period.valid === 1'b1)
                meas = dut.u_get_period.period;
        end
        $display("  recovered %0d", meas);
        if (meas < 1990 || meas > 2010) begin
            $display("FAIL: no recovery after saturation");
            $fatal(1);
        end

        $display("PASS");
        $finish;
    end
endmodule
