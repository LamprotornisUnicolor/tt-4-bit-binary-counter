module popcount13 (
    input  wire        clk,
    input  wire        rst,
    input  wire [12:0] data,
    output reg  [3:0]  count
);
    integer   i;
    reg [3:0] sum;

    // Combinational popcount. Blocking assignments belong here, not in the
    // clocked process below. The {3'b0, data[i]} zero-extends the bit-select
    // to the width of `sum` so the add has matching operand widths.
    always @(*) begin
        sum = 4'd0;
        for (i = 0; i < 13; i = i + 1)
            sum = sum + {3'b0, data[i]};
    end

    // Registered result: non-blocking assignment only.
    always @(posedge clk) begin
        if (rst)
            count <= 4'd0;
        else
            count <= sum;
    end
endmodule
