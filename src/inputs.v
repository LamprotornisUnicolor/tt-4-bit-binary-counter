// Pin aggregation for the Tiny Tapeout pinout.
//
//   ui_in[0]    -> sel_440      force the internal 440 Hz reference
//   ui_in[7:1]  -> chord[6:0]   lower 7 chord bits  (dedicated input pins 1..7)
//   uio_in[5:0] -> chord[12:6]  upper 6 chord bits  (bidirectional pins 0..5)
//   uio_in[6]   -> sqr_ext      external square wave input
//
// The square wave fed to get_period is sqr_ext, unless sel_440 is asserted,
// in which case the tt_um_lamprotornisunicolor_4_bit_binary_counter-level internal 440 Hz oscillator is used instead.

//`timescale 1ns/1ps

module inputs (
    input  wire [7:0]  ui_in,     // dedicated inputs
    input  wire [7:0]  uio_in,    // bidirectional pins, used here as inputs
    output wire        sel_440,   // 1 = use internal 440 Hz reference
    output wire        sqr_ext,   // external square wave
    output wire [12:0] chord      // chord select bus
);

    assign sel_440 = ui_in[0];
    assign sqr_ext = uio_in[6];
    assign chord   = { uio_in[5:0], ui_in[7:1] };

endmodule
