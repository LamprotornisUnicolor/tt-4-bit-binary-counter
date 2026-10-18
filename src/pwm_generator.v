//This is the pwm generation module
//Intended working principle: the counter period is equal to the number of tones in the chord
//The clock divider intends to keep the pwm period similar between different chord sizes
//If chord size is zero - output stays zero
//If chord size is one and value one - output is one
//Some inconsistencies are A-Ok, for even chord sizes, as that should effect volume, not frequencies


module pwm_generator (
    input  wire clk,
    input  wire rst,
    input wire [3:0] chord_size,
    input wire chord_update,
    input wire [3:0] value,


    output reg  output_pwm
);

    reg [3:0] clkdiv;
    reg [3:0] clkdiv_intern;
    reg [3:0] counter;
    always @(posedge clk) begin
        if (rst) begin
            clkdiv        <= 4'd1;
            clkdiv_intern <= 4'd0;
            counter       <= 4'd0;
            output_pwm    <= 1'b0;
        end
        else begin
            if (chord_update) begin
                clkdiv  <= 4'd14 - chord_size;
                counter <= 4'd0;
            end

            clkdiv_intern <= clkdiv_intern + 4'd1;
            if (clkdiv_intern == clkdiv) begin
                clkdiv_intern <= 4'd0;
                counter       <= counter + 4'd1;
                if (counter == (value >> 1)) begin
                    output_pwm <= 1'b1;
                end
                if (counter == value) begin
                    output_pwm <= 1'b0;
                    counter    <= 4'd0;
                end
            end
        end
    end

endmodule
