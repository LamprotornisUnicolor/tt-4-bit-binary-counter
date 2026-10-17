module chord_gen (
    input  wire clk,
    input  wire rst,
    input  wire [12:0] chord,
    input  wire chord_update,
    input  wire [19:0] period,
    output wire [3:0] chord_size,
    output wire [3:0] value
);


//1.11 fixed point multiplier table of semitones, 

localparam [11:0] PERIOD_MUL_0  = 12'd2048; // 1.000000
localparam [11:0] PERIOD_MUL_1  = 12'd1933; // 0.943874
localparam [11:0] PERIOD_MUL_2  = 12'd1825; // 0.890899
localparam [11:0] PERIOD_MUL_3  = 12'd1722; // 0.840896
localparam [11:0] PERIOD_MUL_4  = 12'd1626; // 0.793701
localparam [11:0] PERIOD_MUL_5  = 12'd1534; // 0.749154
localparam [11:0] PERIOD_MUL_6  = 12'd1448; // 0.707107
localparam [11:0] PERIOD_MUL_7  = 12'd1367; // 0.667420
localparam [11:0] PERIOD_MUL_8  = 12'd1290; // 0.629961
localparam [11:0] PERIOD_MUL_9  = 12'd1218; // 0.594604
localparam [11:0] PERIOD_MUL_10 = 12'd1150; // 0.561231
localparam [11:0] PERIOD_MUL_11 = 12'd1085; // 0.529732
localparam [11:0] PERIOD_MUL_12 = 12'd1024; // 0.500000

// Period registers hold only the integer part of period * PERIOD_MUL_k:
// sqr_gen's counter_max is 20 bits and is fed product[31:12], so storing that
// 20-bit value directly instead of the full 32-bit product saves 13*12 = 156 flops.
reg [19:0] PERIOD_0, PERIOD_1, PERIOD_2, PERIOD_3, PERIOD_4, PERIOD_5;
reg [19:0] PERIOD_6, PERIOD_7, PERIOD_8, PERIOD_9, PERIOD_10, PERIOD_11, PERIOD_12;
wire [12:0] output_bits;

    // Serialized period computation: chord_update fires only once per recovered
    // period (~22727 clk at the 440 Hz reference), so the 13 period values are
    // computed one per clock through a single shared multiplier rather than by
    // 13 parallel constant multipliers. This replaces ~7800 gates of adder trees
    // with one 20x12 multiplier plus a mux/demux, at the cost of a 13-cycle
    // latency that is invisible next to the ~22k-cycle update rate.
    reg  [3:0]  mul_idx;    // which period is being computed
    reg         mul_busy;   // sequence in progress
    reg  [11:0] mul_const;  // current semitone multiplier

    wire [31:0] product = period * mul_const;   // only bits [31:12] are kept

    always @(*) begin
        case (mul_idx)
            4'd0:    mul_const = PERIOD_MUL_0;
            4'd1:    mul_const = PERIOD_MUL_1;
            4'd2:    mul_const = PERIOD_MUL_2;
            4'd3:    mul_const = PERIOD_MUL_3;
            4'd4:    mul_const = PERIOD_MUL_4;
            4'd5:    mul_const = PERIOD_MUL_5;
            4'd6:    mul_const = PERIOD_MUL_6;
            4'd7:    mul_const = PERIOD_MUL_7;
            4'd8:    mul_const = PERIOD_MUL_8;
            4'd9:    mul_const = PERIOD_MUL_9;
            4'd10:   mul_const = PERIOD_MUL_10;
            4'd11:   mul_const = PERIOD_MUL_11;
            default: mul_const = PERIOD_MUL_12;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            mul_busy <= 1'b0;
            mul_idx  <= 4'd0;
        end else if (chord_update) begin
            mul_busy <= 1'b1;       // (re)start the sequence
            mul_idx  <= 4'd0;
        end else if (mul_busy) begin
            case (mul_idx)
                4'd0:    PERIOD_0  <= product[31:12];
                4'd1:    PERIOD_1  <= product[31:12];
                4'd2:    PERIOD_2  <= product[31:12];
                4'd3:    PERIOD_3  <= product[31:12];
                4'd4:    PERIOD_4  <= product[31:12];
                4'd5:    PERIOD_5  <= product[31:12];
                4'd6:    PERIOD_6  <= product[31:12];
                4'd7:    PERIOD_7  <= product[31:12];
                4'd8:    PERIOD_8  <= product[31:12];
                4'd9:    PERIOD_9  <= product[31:12];
                4'd10:   PERIOD_10 <= product[31:12];
                4'd11:   PERIOD_11 <= product[31:12];
                default: PERIOD_12 <= product[31:12];
            endcase

            if (mul_idx == 4'd12)
                mul_busy <= 1'b0;
            else
                mul_idx <= mul_idx + 4'd1;
        end
    end

    popcount13 popcount_chordsize(.clk(clk), .rst(rst), .data(chord), .count(chord_size));

    sqr_gen osci0(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_0),
    .level(output_bits[0])
    );
     sqr_gen osci1(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_1),
    .level(output_bits[1])
    );
    sqr_gen osci2(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_2),
    .level(output_bits[2])
    );
    sqr_gen osci3(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_3),
    .level(output_bits[3])
    );
    sqr_gen osci4(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_4),
    .level(output_bits[4])
    );
    sqr_gen osci5(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_5),
    .level(output_bits[5])
    );
    sqr_gen osci6(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_6),
    .level(output_bits[6])
    );
    sqr_gen osci7(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_7),
    .level(output_bits[7])
    );
    sqr_gen osci8(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_8),
    .level(output_bits[8])
    );
    sqr_gen osci9(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_9),
    .level(output_bits[9])
    );
    sqr_gen osci10(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_10),
    .level(output_bits[10])
    );
    sqr_gen osci11(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_11),
    .level(output_bits[11])
    );
    sqr_gen osci12(
    .clk(clk), .rst(rst),
    .counter_max(PERIOD_12),
    .level(output_bits[12])
    );

    // Gate the oscillators with the chord mask: only an oscillator whose key
    // is actually pressed contributes to the volume (PWM duty) value.
    // Bit k of `chord` enables oscillator k. This matches the pin mapping in
    // inputs.v, where chord[6:0] comes from ui_in[7:1] and chord[12:6] from
    // uio_in[5:0], so chord[k] is the key wired to that oscillator's period.
    wire [12:0] active_bits = output_bits & chord;

    popcount13 popcount_volume (.clk(clk), .rst(rst), .data(active_bits), .count(value));

    //always @(posedge clk) begin

    //end

endmodule
