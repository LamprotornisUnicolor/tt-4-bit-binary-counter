// Top level for the chord / PWM audio generator.
//
// Signal path:
//   inputs  -> sqr (external or internal 440 Hz) -> get_period -> period
//   chord   -> chord_gen (clocked with clk, period = recovered period)
//           -> chord_size + value -> pwm_generator -> pwm_out
//
// Pin map:
//   ui_in[0]    sel_440    force 440 Hz reference
//   ui_in[7:1]  chord[6:0]
//   uio_in[5:0] chord[12:6]
//   uio_in[6]   sqr_ext    external square wave
//   uo_out[0]   pwm_out    audio output
//   uio_out[7]  sqr        square-wave monitor (pin 7 driven as output)

//`timescale 1ns/1ps

module tt_um_lamprotornisunicolor_4_bit_binary_counter (
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

    // ---- Internal 440 Hz reference: 10 MHz / (2 * 440) = 11364 clocks ------
    localparam [16:0] HALF_440 = 17'd11364;
    reg [16:0] cnt440;
    reg        sqr_440;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt440  <= 17'd0;
            sqr_440 <= 1'b0;
        end
        else if (cnt440 == HALF_440 - 17'd1) begin
            cnt440  <= 17'd0;
            sqr_440 <= ~sqr_440;
        end
        else begin
            cnt440 <= cnt440 + 17'd1;
        end
    end

    wire sqr_in = sel_440 ? sqr_440 : sqr_ext;

    // ---- Recover the period of the square wave -----------------------------
    wire        period_valid;
    wire        period_idle;
    wire [19:0] period;

    get_period u_get_period (
        .clk    (clk),
        .rst_n  (rst_n),
        .sqr_in (sqr_in),
        .valid  (period_valid),
        .idle   (period_idle),
        .period (period)
    );

    // ---- Expand the measured period into a chord ---------------------------
    wire [3:0] chord_size;
    wire [3:0] chord_value;

    chord_gen u_chord_gen (
        .clk          (clk),
        .rst          (~rst_n),        // chord_gen reset is active-high
        .chord        (chord),
        .chord_update (period_valid),
        .period       (period),
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

    // ---- Output pins -------------------------------------------------------
    assign uo_out  = { 7'b0, pwm_out };   // audio on uo_out[0]
    assign uio_out = { sqr_in, 7'b0 };    // square-wave monitor on pin 7
    assign uio_oe  = 8'b1000_0000;        // pin 7 = output, pins 0..6 = inputs

endmodule
