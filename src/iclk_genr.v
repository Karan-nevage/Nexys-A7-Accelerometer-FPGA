`timescale 1ns / 1ps


module iclk_genr(
    input CLK100MHZ,        // nexys a7 sys clk
    output clk_4MHz         // 4MHz clk
);
    
    reg [4:0] counter = 5'b0;
    reg clk_reg = 1'b1;
    
    always @(posedge CLK100MHZ) begin
        if(counter == 12)                   // 0-12 is 13 ticks
            clk_reg <= ~clk_reg;

        if(counter == 24) begin             // 13-24 is 12 ticks
            clk_reg <= ~clk_reg;
            counter <= 5'b0;                // reset counter
        end
        
        else
            counter <= counter + 1;
    end

    assign clk_4MHz = clk_reg;

endmodule