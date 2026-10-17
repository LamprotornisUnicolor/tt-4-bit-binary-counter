module sqr_gen (
    input wire clk,
    input wire rst,
    input wire[19:0] counter_max,
    output reg level
);
reg [19:0] count;
    always @(posedge clk) begin
        if (rst) begin
            count <= 20'd0;
            level <= 1'd0;
        end else begin     
            count <= count + 20'd1;


            if (count == (counter_max>>1)) level <= 1'd0;

            if (count == counter_max) begin 
                level <= 1'd1;
                count <= 20'd0;
            end 
        end

    end

endmodule
