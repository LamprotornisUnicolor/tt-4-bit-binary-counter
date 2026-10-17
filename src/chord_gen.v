module chord_gen (
    input  wire        clk,
    input  wire        rst,
    input  wire [12:0] chord,
    input  wire        chord_update,
    // Period of the input square, in clocks of the 2 MHz clock.
    input  wire [16:0] period,
    output wire [3:0]  chord_size,
    output wire [3:0]  value
);
    // Fixed terminal counts. Voice 0 wraps at 128.
    // Voice 12 wraps at 64, so it is one octave higher.
    // The other counts are round(128 * 2^(-k/12)).
    function [7:0] top_of;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:    top_of = 8'd128;
                4'd1:    top_of = 8'd121;
                4'd2:    top_of = 8'd114;
                4'd3:    top_of = 8'd108;
                4'd4:    top_of = 8'd102;
                4'd5:    top_of = 8'd96;
                4'd6:    top_of = 8'd91;
                4'd7:    top_of = 8'd85;
                4'd8:    top_of = 8'd81;
                4'd9:    top_of = 8'd76;
                4'd10:   top_of = 8'd72;
                4'd11:   top_of = 8'd68;
                default: top_of = 8'd64;
            endcase
        end
    endfunction

    function [6:0] half_of;
        input [3:0] idx;
        reg [7:0] top;
        begin
            top     = top_of(idx);
            half_of = top[7:1];
        end
    endfunction

    reg [6:0]  phase [0:12];
    reg [16:0] acc;
    reg [16:0] period_r;
    reg        armed;

    // Add the unison top every clock. One tick when the sum reaches
    // the measured period. Voice 0 then matches that period.
    // A period below 128 is faster than clk/128 (about 15.6 kHz).
    // The voices then run at that limit.
    wire [17:0] sum_w = {1'b0, acc} + 18'd128;
    wire        fast  = (period_r < 17'd128);
    wire        tick  = armed && (fast || (sum_w >= {1'b0, period_r}));

    wire [12:0] level;
    genvar gi;
    generate
        for (gi = 0; gi < 13; gi = gi + 1) begin : voice_level
            assign level[gi] = armed && (phase[gi] < half_of(gi));
        end
    endgenerate

    wire [12:0] active_bits = level & chord;

    popcount13 popcount_chordsize (
        .clk   (clk),
        .rst   (rst),
        .data  (chord),
        .count (chord_size)
    );

    popcount13 popcount_volume (
        .clk   (clk),
        .rst   (rst),
        .data  (active_bits),
        .count (value)
    );

    always @(posedge clk) begin : seq
        integer vi;
        if (rst) begin
            acc      <= 17'd0;
            period_r <= 17'd0;
            armed    <= 1'b0;
            for (vi = 0; vi < 13; vi = vi + 1)
                phase[vi] <= 7'd0;
        end else begin
            if (chord_update) begin
                period_r <= period;
                armed    <= (period != 17'd0);
            end

            if (tick) begin
                if (fast)
                    acc <= 17'd0;
                else
                    acc <= sum_w[16:0] - period_r;
                for (vi = 0; vi < 13; vi = vi + 1) begin
                    if (({1'b0, phase[vi]} + 8'd1) >= top_of(vi))
                        phase[vi] <= 7'd0;
                    else
                        phase[vi] <= phase[vi] + 7'd1;
                end
            end else if (!armed || (chord_update && (acc >= period))) begin
                acc <= 17'd0;
            end else begin
                acc <= sum_w[16:0];
            end
        end
    end
endmodule
