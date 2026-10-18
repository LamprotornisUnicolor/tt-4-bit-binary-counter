// Top level for the chord / PWM audio generator.
//
// Signal path:
//   inputs  -> sqr (external or internal 440 Hz) -> get_period
//   chord   -> chord_gen (fixed tops, one clock divider)
//           -> chord_size + value -> pwm_generator -> pwm_out
//
// The clock is 2 MHz. Output tones are 20 Hz to about 15 kHz.
//
// Pin map:
//   ui_in[0]    sel_440    force 440 Hz reference
//   ui_in[7:1]  chord[6:0]
//   uio_in[5:0] chord[12:6]
//   uio_in[6]   sqr_ext    external square wave
//   uo_out[7]   pwm_out    audio to the Tiny Tapeout Audio Pmod (out[7])
//   uo_out[0]   sqr        square-wave monitor
//   uio_oe      0          every bidirectional pin is an input

//`timescale 1ns/1ps

module tt_um_chord_synth_lamprotornisunicolor (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ---- Pin aggregation ---------------------------------------------------
    wire        sel_440;
    wire        sqr_ext;
    wire [12:0] chord;

    inputs u_inputs (
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .sel_440(sel_440),
        .sqr_ext(sqr_ext),
        .chord  (chord)
    );

    // 2 MHz / (2 * 440) = 2272.7 clocks. 2273 gives 439.95 Hz.
    localparam [11:0] HALF_440 = 12'd2273;
    reg [11:0] cnt440;
    reg        sqr_440;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt440  <= 12'd0;
            sqr_440 <= 1'b0;
        end
        else if (cnt440 == HALF_440 - 12'd1) begin
            cnt440  <= 12'd0;
            sqr_440 <= ~sqr_440;
        end
        else begin
            cnt440 <= cnt440 + 12'd1;
        end
    end

    wire sqr_in = sel_440 ? sqr_440 : sqr_ext;

    // ---- Recover the period of the square wave -----------------------------
    wire        period_valid;
    wire        period_idle;
    wire [16:0] period_len;

    get_period u_get_period (
        .clk    (clk),
        .rst_n  (rst_n),
        .sqr_in (sqr_in),
        .valid  (period_valid),
        .idle   (period_idle),
        .period (period_len)
    );

    // ---- Expand the measured period into a chord ---------------------------
    wire [3:0] chord_size;
    wire [3:0] chord_value;

    chord_gen u_chord_gen (
        .clk          (clk),
        .rst          (~rst_n),        // chord_gen reset is active-high
        .chord        (chord),
        .chord_update (period_valid),
        .period       (period_len),
        .chord_size   (chord_size),
        .value        (chord_value)
    );

    // ---- PWM audio output --------------------------------------------------
    wire pwm_out;

    pwm_generator u_pwm (
        .clk          (clk),
        .rst          (~rst_n),        // pwm_generator reset is active-high
        .chord_size   (chord_size),
        .chord_update (period_valid),
        .value        (chord_value),
        .output_pwm   (pwm_out)
    );

    // Audio Pmod reads PWM from out[7]. out[6:1] stay low.
    // The square monitor is on out[0]. All bidirectional pins are inputs.
    // ena is a required port. period_idle is a status flag. uio_in[7] has
    // no pin function. Read them so they are not unused nets.
    wire _unused = &{ena, period_idle, uio_in[7], 1'b0};
    assign uo_out  = { pwm_out, 6'b0, sqr_in };
    assign uio_out = 8'b0;
    assign uio_oe  = {7'b0, _unused & 1'b0};

endmodule
