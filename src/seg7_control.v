`timescale 1ns / 1ps

module seg7_control (
    input  wire CLK100MHZ,         // Nexys A7 system clock (100 MHz)
    input  wire [14:0] acl_data,   // 15-bit accelerometer data (5 bits per axis: X, Y, Z)
    output reg  [6:0] seg,         // 7-segment display segments
    output reg  dp,                // Decimal point for 7-segment display
    output reg  [7:0] an           // 8 anode signals for 7-segment display
);

    // Extract sign bits from accelerometer data
    wire x_sign, y_sign, z_sign;
    assign x_sign = acl_data[14];    // Sign bit for X-axis
    assign y_sign = acl_data[9];     // Sign bit for Y-axis
    assign z_sign = acl_data[4];     // Sign bit for Z-axis

    // Extract 6-bit data for each axis (only using 4 bits here)
    wire [3:0] x_data, y_data, z_data;
    assign x_data = acl_data[13:10]; // X-axis data (4 bits)
    assign y_data = acl_data[8:5];   // Y-axis data (4 bits)
    assign z_data = acl_data[3:0];   // Z-axis data (4 bits)

    // Binary to BCD conversion for each axis (using 4-bit data)
    wire [3:0] x_10, x_1, y_10, y_1, z_10, z_1;
    assign x_10 = x_data / 10;       // Tens digit for X-axis
    assign x_1  = x_data % 10;       // Ones digit for X-axis
    assign y_10 = y_data / 10;       // Tens digit for Y-axis
    assign y_1  = y_data % 10;       // Ones digit for Y-axis
    assign z_10 = z_data / 10;       // Tens digit for Z-axis
    assign z_1  = z_data % 10;       // Ones digit for Z-axis

    // Parameters for 7-segment display patterns
    parameter ZERO  = 7'b000_0001;  // 0
    parameter ONE   = 7'b100_1111;  // 1
    parameter TWO   = 7'b001_0010;  // 2
    parameter THREE = 7'b000_0110;  // 3
    parameter FOUR  = 7'b100_1100;  // 4
    parameter FIVE  = 7'b010_0100;  // 5
    parameter SIX   = 7'b010_0000;  // 6
    parameter SEVEN = 7'b000_1111;  // 7
    parameter EIGHT = 7'b000_0000;  // 8
    parameter NINE  = 7'b000_0100;  // 9
    parameter NULL  = 7'b111_1111;  // All segments OFF

    // Internal registers for anode control
    reg [2:0] anode_select = 3'b0;    // 3-bit counter to select each of 8 anodes
    reg [16:0] anode_timer = 17'b0;   // Counter for anode refresh (1ms period)

    // Logic to control anode selection and timer
    always @(posedge CLK100MHZ) begin               // 1ms x 8 displays = 8ms refresh period                             
        if (anode_timer == 99_999) begin             // The period of 100MHz clock is 10ns (1/100,000,000 seconds)
            anode_timer  <= 0;                       // 10ns x 100,000 = 1ms
            anode_select <= anode_select + 1;
        end
        else
            anode_timer <= anode_timer + 1;
    end

    // Logic to drive 8-bit anode output based on anode select
    always @(anode_select) begin
        case (anode_select) 
            3'b000 : an = 8'b1111_1110;   
            3'b001 : an = 8'b1111_1101;  
            3'b010 : an = 8'b1111_1011;  
            3'b011 : an = 8'b1111_0111;
            3'b100 : an = 8'b1110_1111;   
            3'b101 : an = 8'b1101_1111;  
            3'b110 : an = 8'b1011_1111;  
            3'b111 : an = 8'b0111_1111; 
        endcase
    end

    // Logic for driving segments based on which anode is selected
    always @*
        case (anode_select)
            3'b000 : begin
                        if (z_sign)                  // if sign is negative
                            dp = 1'b0;              // ON
                        else
                            dp = 1'b1;              // OFF 
                                
                        case (z_1)                   // Z axis ones digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
                    
            3'b001 : begin  
                        dp = 1'b1;                  // OFF  
                        
                        case (z_10)                  // Z axis tens digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
                    
            3'b010 : begin                          // anode not used
                        dp = 1'b1;
                        seg = NULL;     
                    end
                    
            3'b011 : begin
                        if (y_sign)                  // if sign is negative
                            dp = 1'b0;              // ON
                        else
                            dp = 1'b1;              // OFF
                        
                        case (y_1)                   // Y axis ones digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
                    
            3'b100 : begin
                        dp = 1'b1;                  // OFF
                         
                        case (y_10)                  // Y axis tens digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
                    
            3'b101 : begin                          // anode not used
                        dp = 1'b1;
                        seg = NULL;    
                    end
                    
            3'b110 : begin 
                        if (x_sign)                  // if sign is negative
                            dp = 1'b0;              // ON
                        else
                            dp = 1'b1;              // OFF
                        
                        case (x_1)                   // X axis ones digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
                    
            3'b111 : begin
                        dp = 1'b1;                  // OFF
                         
                        case (x_10)                  // X axis tens digit
                            4'b0000 : seg = ZERO;
                            4'b0001 : seg = ONE;
                            4'b0010 : seg = TWO;
                            4'b0011 : seg = THREE;
                            4'b0100 : seg = FOUR;
                            4'b0101 : seg = FIVE;
                            4'b0110 : seg = SIX;
                            4'b0111 : seg = SEVEN;
                            4'b1000 : seg = EIGHT;
                            4'b1001 : seg = NINE;
                        endcase
                    end
        endcase 

endmodule
