module get_period (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sqr_in,
    output reg         valid,
    output reg         idle,
    // Clocks between rising edges. The chip clock is 2 MHz.
    // 100000 clocks is 20 Hz. A slower input is out of range.
    output reg  [16:0] period
);
    localparam IDLE = 2'd0, HIGH = 2'd1, LOW = 2'd2, SATURATED = 2'd3;
    localparam FALSE = 1'b0, TRUE = 1'b1;

    localparam [16:0] SAT_VAL = 17'd100000;

    reg [1:0]  state;
    reg [16:0] count;
    reg        sqr_in1, sqr_in2, sqr_del;

    always @(posedge clk) begin
        sqr_in1 <= sqr_in;
        sqr_in2 <= sqr_in1;
        valid   <= FALSE;
        if (!rst_n) begin
            state   <= IDLE;
            count   <= 17'd0;
            idle    <= 1'b0;
            sqr_del <= FALSE;
            period  <= 17'd0;
        end else begin
            case (state)
                IDLE: begin
                    idle <= TRUE;
                    if (sqr_in2 ^ sqr_del) begin
                        sqr_del <= sqr_in2;
                        if (sqr_in2) begin
                            state <= HIGH;
                            idle  <= FALSE;
                        end
                    end
                end
                HIGH: begin
                    count <= count + 17'd1;
                    if (sqr_in2) begin
                        if (count == SAT_VAL)
                            state <= SATURATED;
                    end else begin
                        state <= LOW;
                    end
                end
                LOW: begin
                    count <= count + 17'd1;
                    if (sqr_in2) begin
                        period <= count;
                        valid  <= TRUE;
                        count  <= 17'd0;
                        state  <= HIGH;
                    end else if (count == SAT_VAL) begin
                        state <= SATURATED;
                    end
                end
                SATURATED: begin
                    count <= 17'd0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
