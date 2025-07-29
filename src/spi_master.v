`timescale 1ns / 1ps

module spi_master (
    input  wire iclk,            // 4 MHz input clock
    input  wire miso,            // Master In Slave Out
    output wire sclk,            // SPI clock (1 MHz)
    output reg  mosi = 1'b0,     // Master Out Slave In, initialized to 0
    output reg  cs = 1'b1,       // Chip Select, initialized to high (inactive)
    output wire [14:0] acl_data  // 15-bit accelerometer data (5 bits per axis)
);

    // Control signal for sclk output
    reg sclk_control = 1'b0;

    // Internal registers for clock division
    reg clk_counter = 1'b0;
    reg clk_reg     = 1'b1;

    // Clock division to generate 1 MHz sclk from 4 MHz iclk
    always @(posedge iclk) begin
        clk_counter <= clk_counter + 1;
        if (clk_counter == 1'b1)
            clk_reg <= ~clk_reg;    // Toggle to generate 1 MHz clock
    end

    // SPI communication parameters
    reg [7:0] write_instr   = 8'h0A;    // Write instruction for sensor
    reg [7:0] mode_reg_addr = 8'h2D;    // Mode register address
    reg [7:0] mode_wr_data  = 8'h02;    // Data to set measurement mode
    reg [7:0] read_instr    = 8'h0B;    // Read instruction for sensor
    reg [7:0] x_LSB_addr    = 8'h0E;    // X data LSB address (auto-increments)
    reg [14:0] temp_DATA    = 15'b0;    // Temporary 15-bit data buffer
    reg [15:0] X = 15'b0;               // X-axis data (MSB and LSB)
    reg [15:0] Y = 15'b0;               // Y-axis data (MSB and LSB)
    reg [15:0] Z = 15'b0;               // Z-axis data (MSB and LSB)
    reg [31:0] counter = 32'b0;         // State machine sync counter
    wire latch_data;

    // State machine parameters (93 states)
    localparam [6:0] POWER_UP    = 7'h00,  // Wait 6ms, CS = 0, SCLK = idle
                     BEGIN_SPIW  = 7'h01,   // Start SPI write
                     SEND_WCMD7  = 7'h02,   // Send write command bit 7
                     SEND_WCMD6  = 7'h03,   // Send write command bit 6
                     SEND_WCMD5  = 7'h04,   // Send write command bit 5
                     SEND_WCMD4  = 7'h05,   // Send write command bit 4
                     SEND_WCMD3  = 7'h06,   // Send write command bit 3
                     SEND_WCMD2  = 7'h07,   // Send write command bit 2
                     SEND_WCMD1  = 7'h08,   // Send write command bit 1
                     SEND_WCMD0  = 7'h09,   // Send write command bit 0
                     SEND_WADDR7 = 7'h0A,   // Send mode register address bit 7
                     SEND_WADDR6 = 7'h0B,   // Send mode register address bit 6
                     SEND_WADDR5 = 7'h0C,   // Send mode register address bit 5
                     SEND_WADDR4 = 7'h0D,   // Send mode register address bit 4
                     SEND_WADDR3 = 7'h0E,   // Send mode register address bit 3
                     SEND_WADDR2 = 7'h0F,   // Send mode register address bit 2
                     SEND_WADDR1 = 7'h10,   // Send mode register address bit 1
                     SEND_WADDR0 = 7'h11,   // Send mode register address bit 0
                     SEND_BYTE7  = 7'h12,   // Send mode data bit 7
                     SEND_BYTE6  = 7'h13,   // Send mode data bit 6
                     SEND_BYTE5  = 7'h14,   // Send mode data bit 5
                     SEND_BYTE4  = 7'h15,   // Send mode data bit 4
                     SEND_BYTE3  = 7'h16,   // Send mode data bit 3
                     SEND_BYTE2  = 7'h17,   // Send mode data bit 2
                     SEND_BYTE1  = 7'h18,   // Send mode data bit 1
                     SEND_BYTE0  = 7'h19,   // Send mode data bit 0
                     WAIT        = 7'h1A,   // Wait 40ms for valid data
                     BEGIN_SPIR  = 7'h1B,   // Start SPI read
                     SEND_RCMD7  = 7'h1C,   // Send read command bit 7
                     SEND_RCMD6  = 7'h1D,   // Send read command bit 6
                     SEND_RCMD5  = 7'h1E,   // Send read command bit 5
                     SEND_RCMD4  = 7'h1F,   // Send read command bit 4
                     SEND_RCMD3  = 7'h20,   // Send read command bit 3
                     SEND_RCMD2  = 7'h21,   // Send read command bit 2
                     SEND_RCMD1  = 7'h22,   // Send read command bit 1
                     SEND_RCMD0  = 7'h23,   // Send read command bit 0
                     SEND_RADDR7 = 7'h24,   // Send X LSB address bit 7
                     SEND_RADDR6 = 7'h25,   // Send X LSB address bit 6
                     SEND_RADDR5 = 7'h26,   // Send X LSB address bit 5
                     SEND_RADDR4 = 7'h27,   // Send X LSB address bit 4
                     SEND_RADDR3 = 7'h28,   // Send X LSB address bit 3
                     SEND_RADDR2 = 7'h29,   // Send X LSB address bit 2
                     SEND_RADDR1 = 7'h2A,   // Send X LSB address bit 1
                     SEND_RADDR0 = 7'h2B,   // Send X LSB address bit 0
                     REC_XLSB7   = 7'h2C,   // Receive X LSB bit 7
                     REC_XLSB6   = 7'h2D,   // Receive X LSB bit 6
                     REC_XLSB5   = 7'h2E,   // Receive X LSB bit 5
                     REC_XLSB4   = 7'h2F,   // Receive X LSB bit 4
                     REC_XLSB3   = 7'h30,   // Receive X LSB bit 3
                     REC_XLSB2   = 7'h31,   // Receive X LSB bit 2
                     REC_XLSB1   = 7'h32,   // Receive X LSB bit 1
                     REC_XLSB0   = 7'h33,   // Receive X LSB bit 0
                     REC_XMSB7   = 7'h34,   // Receive X MSB bit 7
                     REC_XMSB6   = 7'h35,   // Receive X MSB bit 6
                     REC_XMSB5   = 7'h36,   // Receive X MSB bit 5
                     REC_XMSB4   = 7'h37,   // Receive X MSB bit 4
                     REC_XMSB3   = 7'h38,   // Receive X MSB bit 3
                     REC_XMSB2   = 7'h39,   // Receive X MSB bit 2
                     REC_XMSB1   = 7'h3A,   // Receive X MSB bit 1
                     REC_XMSB0   = 7'h3B,   // Receive X MSB bit 0
                     REC_YLSB7   = 7'h3C,   // Receive Y LSB bit 7
                     REC_YLSB6   = 7'h3D,   // Receive Y LSB bit 6
                     REC_YLSB5   = 7'h3E,   // Receive Y LSB bit 5
                     REC_YLSB4   = 7'h3F,   // Receive Y LSB bit 4
                     REC_YLSB3   = 7'h40,   // Receive Y LSB bit 3
                     REC_YLSB2   = 7'h41,   // Receive Y LSB bit 2
                     REC_YLSB1   = 7'h42,   // Receive Y LSB bit 1
                     REC_YLSB0   = 7'h43,   // Receive Y LSB bit 0
                     REC_YMSB7   = 7'h44,   // Receive Y MSB bit 7
                     REC_YMSB6   = 7'h45,   // Receive Y MSB bit 6
                     REC_YMSB5   = 7'h46,   // Receive Y MSB bit 5
                     REC_YMSB4   = 7'h47,   // Receive Y MSB bit 4
                     REC_YMSB3   = 7'h48,   // Receive Y MSB bit 3
                     REC_YMSB2   = 7'h49,   // Receive Y MSB bit 2
                     REC_YMSB1   = 7'h4A,   // Receive Y MSB bit 1
                     REC_YMSB0   = 7'h4B,   // Receive Y MSB bit 0
                     REC_ZLSB7   = 7'h4C,   // Receive Z LSB bit 7
                     REC_ZLSB6   = 7'h4D,   // Receive Z LSB bit 6
                     REC_ZLSB5   = 7'h4E,   // Receive Z LSB bit 5
                     REC_ZLSB4   = 7'h4F,   // Receive Z LSB bit 4
                     REC_ZLSB3   = 7'h50,   // Receive Z LSB bit 3
                     REC_ZLSB2   = 7'h51,   // Receive Z LSB bit 2
                     REC_ZLSB1   = 7'h52,   // Receive Z LSB bit 1
                     REC_ZLSB0   = 7'h53,   // Receive Z LSB bit 0
                     REC_ZMSB7   = 7'h54,   // Receive Z MSB bit 7
                     REC_ZMSB6   = 7'h55,   // Receive Z MSB bit 6
                     REC_ZMSB5   = 7'h56,   // Receive Z MSB bit 5
                     REC_ZMSB4   = 7'h57,   // Receive Z MSB bit 4
                     REC_ZMSB3   = 7'h58,   // Receive Z MSB bit 3
                     REC_ZMSB2   = 7'h59,   // Receive Z MSB bit 2
                     REC_ZMSB1   = 7'h5A,   // Receive Z MSB bit 1
                     REC_ZMSB0   = 7'h5B,   // Receive Z MSB bit 0
                     END_SPI     = 7'h5C;   // Wait 10ms, loop back to BEGIN_SPIR

    // State register initialization
    reg [6:0] state_reg = POWER_UP;    // Initial state

    // State machine logic triggered on positive edge of iclk
    always @(posedge iclk) begin
        counter <= counter + 1;    // Increment state machine sync counter
        case (state_reg)
            POWER_UP : begin
                if (counter == 32'd23999)    // Wait for 6ms, for sensor to reach standby mode
                    state_reg <= BEGIN_SPIW;
            end

            BEGIN_SPIW : begin            // Start SPI write
                if (counter == 32'd24001) begin
                    state_reg <= SEND_WCMD7;
                    cs <= 1'b0;              // Activate chip select
                end
            end

            SEND_WCMD7 : begin            // Send write command bit 7
                sclk_control <= 1'b1;      // Enable sclk for CPHA = 0
                mosi <= write_instr[7];
                if (counter == 32'd24005)
                    state_reg <= SEND_WCMD6;
            end
            SEND_WCMD6 : begin            // Send write command bit 6
                mosi <= write_instr[6];
                if (counter == 32'd24009)
                    state_reg <= SEND_WCMD5;
            end
            SEND_WCMD5 : begin            // Send write command bit 5
                mosi <= write_instr[5];
                if (counter == 32'd24013)
                    state_reg <= SEND_WCMD4;
            end
            SEND_WCMD4 : begin            // Send write command bit 4
                mosi <= write_instr[4];
                if (counter == 32'd24017)
                    state_reg <= SEND_WCMD3;
            end
            SEND_WCMD3 : begin            // Send write command bit 3
                mosi <= write_instr[3];
                if (counter == 32'd24021)
                    state_reg <= SEND_WCMD2;
            end
            SEND_WCMD2 : begin            // Send write command bit 2
                mosi <= write_instr[2];
                if (counter == 32'd24025)
                    state_reg <= SEND_WCMD1;
            end
            SEND_WCMD1 : begin            // Send write command bit 1
                mosi <= write_instr[1];
                if (counter == 32'd24029)
                    state_reg <= SEND_WCMD0;
            end
            SEND_WCMD0 : begin            // Send write command bit 0
                mosi <= write_instr[0];
                if (counter == 32'd24033)
                    state_reg <= SEND_WADDR7;
            end

            SEND_WADDR7 : begin           // Send mode register address bit 7
                mosi <= mode_reg_addr[7];
                if (counter == 32'd24037)
                    state_reg <= SEND_WADDR6;
            end
            SEND_WADDR6 : begin           // Send mode register address bit 6
                mosi <= mode_reg_addr[6];
                if (counter == 32'd24041)
                    state_reg <= SEND_WADDR5;
            end
            SEND_WADDR5 : begin           // Send mode register address bit 5
                mosi <= mode_reg_addr[5];
                if (counter == 32'd24045)
                    state_reg <= SEND_WADDR4;
            end
            SEND_WADDR4 : begin           // Send mode register address bit 4
                mosi <= mode_reg_addr[4];
                if (counter == 32'd24049)
                    state_reg <= SEND_WADDR3;
            end
            SEND_WADDR3 : begin           // Send mode register address bit 3
                mosi <= mode_reg_addr[3];
                if (counter == 32'd24053)
                    state_reg <= SEND_WADDR2;
            end
            SEND_WADDR2 : begin           // Send mode register address bit 2
                mosi <= mode_reg_addr[2];
                if (counter == 32'd24057)
                    state_reg <= SEND_WADDR1;
            end
            SEND_WADDR1 : begin           // Send mode register address bit 1
                mosi <= mode_reg_addr[1];
                if (counter == 32'd24061)
                    state_reg <= SEND_WADDR0;
            end
            SEND_WADDR0 : begin           // Send mode register address bit 0
                mosi <= mode_reg_addr[0];
                if (counter == 32'd24065)
                    state_reg <= SEND_BYTE7;
            end

            SEND_BYTE7 : begin            // Send mode data bit 7
                mosi <= mode_wr_data[7];
                if (counter == 32'd24069)
                    state_reg <= SEND_BYTE6;
            end
            SEND_BYTE6 : begin            // Send mode data bit 6
                mosi <= mode_wr_data[6];
                if (counter == 32'd24073)
                    state_reg <= SEND_BYTE5;
            end
            SEND_BYTE5 : begin            // Send mode data bit 5
                mosi <= mode_wr_data[5];
                if (counter == 32'd24077)
                    state_reg <= SEND_BYTE4;
            end
            SEND_BYTE4 : begin            // Send mode data bit 4
                mosi <= mode_wr_data[4];
                if (counter == 32'd24081)
                    state_reg <= SEND_BYTE3;
            end
            SEND_BYTE3 : begin            // Send mode data bit 3
                mosi <= mode_wr_data[3];
                if (counter == 32'd24085)
                    state_reg <= SEND_BYTE2;
            end
            SEND_BYTE2 : begin            // Send mode data bit 2
                mosi <= mode_wr_data[2];
                if (counter == 32'd24089)
                    state_reg <= SEND_BYTE1;
            end
            SEND_BYTE1 : begin            // Send mode data bit 1
                mosi <= mode_wr_data[1];
                if (counter == 32'd24093)
                    state_reg <= SEND_BYTE0;
            end
            SEND_BYTE0 : begin            // Send mode data bit 0
                mosi <= mode_wr_data[0];
                if (counter == 32'd24097) begin
                    state_reg <= WAIT;
                    counter   <= 32'd0;       // Reset counter
                    cs        <= 1'b1;        // Deactivate chip select
                    sclk_control <= 1'b0;     // Deactivate sclk
                end
            end

            WAIT : begin                   // Wait 40ms for valid data
                if (counter == 32'd160002) begin
                    counter   <= 32'd0;     // Reset counter
                    state_reg <= BEGIN_SPIR;
                end
            end

            BEGIN_SPIR : begin             // Start SPI read
                if (counter == 32'd1) begin
                    state_reg    <= SEND_RCMD7;
                    cs           <= 1'b0;    // Activate chip select
                    sclk_control <= 1'b1;    // Enable sclk
                end
            end

            SEND_RCMD7 : begin             // Send read command bit 7
                mosi <= read_instr[7];
                if (counter == 32'd4)
                    state_reg <= SEND_RCMD6;
            end
            SEND_RCMD6 : begin             // Send read command bit 6
                mosi <= read_instr[6];
                if (counter == 32'd8)
                    state_reg <= SEND_RCMD5;
            end
            SEND_RCMD5 : begin             // Send read command bit 5
                mosi <= read_instr[5];
                if (counter == 32'd12)
                    state_reg <= SEND_RCMD4;
            end
            SEND_RCMD4 : begin             // Send read command bit 4
                mosi <= read_instr[4];
                if (counter == 32'd16)
                    state_reg <= SEND_RCMD3;
            end
            SEND_RCMD3 : begin             // Send read command bit 3
                mosi <= read_instr[3];
                if (counter == 32'd20)
                    state_reg <= SEND_RCMD2;
            end
            SEND_RCMD2 : begin             // Send read command bit 2
                mosi <= read_instr[2];
                if (counter == 32'd24)
                    state_reg <= SEND_RCMD1;
            end
            SEND_RCMD1 : begin             // Send read command bit 1
                mosi <= read_instr[1];
                if (counter == 32'd28)
                    state_reg <= SEND_RCMD0;
            end
            SEND_RCMD0 : begin             // Send read command bit 0
                mosi <= read_instr[0];
                if (counter == 32'd32)
                    state_reg <= SEND_RADDR7;
            end

            SEND_RADDR7 : begin            // Send X LSB address bit 7
                mosi <= x_LSB_addr[7];
                if (counter == 32'd36)
                    state_reg <= SEND_RADDR6;
            end
            SEND_RADDR6 : begin            // Send X LSB address bit 6
                mosi <= x_LSB_addr[6];
                if (counter == 32'd40)
                    state_reg <= SEND_RADDR5;
            end
            SEND_RADDR5 : begin            // Send X LSB address bit 5
                mosi <= x_LSB_addr[5];
                if (counter == 32'd44)
                    state_reg <= SEND_RADDR4;
            end
            SEND_RADDR4 : begin            // Send X LSB address bit 4
                mosi <= x_LSB_addr[4];
                if (counter == 32'd48)
                    state_reg <= SEND_RADDR3;
            end
            SEND_RADDR3 : begin            // Send X LSB address bit 3
                mosi <= x_LSB_addr[3];
                if (counter == 32'd52)
                    state_reg <= SEND_RADDR2;
            end
            SEND_RADDR2 : begin            // Send X LSB address bit 2
                mosi <= x_LSB_addr[2];
                if (counter == 32'd56)
                    state_reg <= SEND_RADDR1;
            end
            SEND_RADDR1 : begin            // Send X LSB address bit 1
                mosi <= x_LSB_addr[1];
                if (counter == 32'd60)
                    state_reg <= SEND_RADDR0;
            end
            SEND_RADDR0 : begin            // Send X LSB address bit 0
                mosi <= x_LSB_addr[0];
                if (counter == 32'd64)
                    state_reg <= REC_XLSB7;
            end

            REC_XLSB7 : begin              // Receive X LSB bit 7
                X[7] <= miso;
                if (counter == 32'd68)
                    state_reg <= REC_XLSB6;
            end
            REC_XLSB6 : begin              // Receive X LSB bit 6
                X[6] <= miso;
                if (counter == 32'd72)
                    state_reg <= REC_XLSB5;
            end
            REC_XLSB5 : begin              // Receive X LSB bit 5
                X[5] <= miso;
                if (counter == 32'd76)
                    state_reg <= REC_XLSB4;
            end
            REC_XLSB4 : begin              // Receive X LSB bit 4
                X[4] <= miso;
                if (counter == 32'd80)
                    state_reg <= REC_XLSB3;
            end
            REC_XLSB3 : begin              // Receive X LSB bit 3
                X[3] <= miso;
                if (counter == 32'd84)
                    state_reg <= REC_XLSB2;
            end
            REC_XLSB2 : begin              // Receive X LSB bit 2
                X[2] <= miso;
                if (counter == 32'd88)
                    state_reg <= REC_XLSB1;
            end
            REC_XLSB1 : begin              // Receive X LSB bit 1
                X[1] <= miso;
                if (counter == 32'd92)
                    state_reg <= REC_XLSB0;
            end
            REC_XLSB0 : begin              // Receive X LSB bit 0
                X[0] <= miso;
                if (counter == 32'd96)
                    state_reg <= REC_XMSB7;
            end

            REC_XMSB7 : begin              // Receive X MSB bit 7
                X[15] <= miso;
                if (counter == 32'd100)
                    state_reg <= REC_XMSB6;
            end
            REC_XMSB6 : begin              // Receive X MSB bit 6
                X[14] <= miso;
                if (counter == 32'd104)
                    state_reg <= REC_XMSB5;
            end
            REC_XMSB5 : begin              // Receive X MSB bit 5
                X[13] <= miso;
                if (counter == 32'd108)
                    state_reg <= REC_XMSB4;
            end
            REC_XMSB4 : begin              // Receive X MSB bit 4
                X[12] <= miso;
                if (counter == 32'd112)
                    state_reg <= REC_XMSB3;
            end
            REC_XMSB3 : begin              // Receive X MSB bit 3
                X[11] <= miso;
                if (counter == 32'd116)
                    state_reg <= REC_XMSB2;
            end
            REC_XMSB2 : begin              // Receive X MSB bit 2
                X[10] <= miso;
                if (counter == 32'd120)
                    state_reg <= REC_XMSB1;
            end
            REC_XMSB1 : begin              // Receive X MSB bit 1
                X[9] <= miso;
                if (counter == 32'd124)
                    state_reg <= REC_XMSB0;
            end
            REC_XMSB0 : begin              // Receive X MSB bit 0
                X[8] <= miso;
                if (counter == 32'd128)
                    state_reg <= REC_YLSB7;
            end

            REC_YLSB7 : begin              // Receive Y LSB bit 7
                Y[7] <= miso;
                if (counter == 32'd132)
                    state_reg <= REC_YLSB6;
            end
            REC_YLSB6 : begin              // Receive Y LSB bit 6
                Y[6] <= miso;
                if (counter == 32'd136)
                    state_reg <= REC_YLSB5;
            end
            REC_YLSB5 : begin              // Receive Y LSB bit 5
                Y[5] <= miso;
                if (counter == 32'd140)
                    state_reg <= REC_YLSB4;
            end
            REC_YLSB4 : begin              // Receive Y LSB bit 4
                Y[4] <= miso;
                if (counter == 32'd144)
                    state_reg <= REC_YLSB3;
            end
            REC_YLSB3 : begin              // Receive Y LSB bit 3
                Y[3] <= miso;
                if (counter == 32'd148)
                    state_reg <= REC_YLSB2;
            end
            REC_YLSB2 : begin              // Receive Y LSB bit 2
                Y[2] <= miso;
                if (counter == 32'd152)
                    state_reg <= REC_YLSB1;
            end
            REC_YLSB1 : begin              // Receive Y LSB bit 1
                Y[1] <= miso;
                if (counter == 32'd156)
                    state_reg <= REC_YLSB0;
            end
            REC_YLSB0 : begin              // Receive Y LSB bit 0
                Y[0] <= miso;
                if (counter == 32'd160)
                    state_reg <= REC_YMSB7;
            end

            REC_YMSB7 : begin              // Receive Y MSB bit 7
                Y[15] <= miso;
                if (counter == 32'd164)
                    state_reg <= REC_YMSB6;
            end
            REC_YMSB6 : begin              // Receive Y MSB bit 6
                Y[14] <= miso;
                if (counter == 32'd168)
                    state_reg <= REC_YMSB5;
            end
            REC_YMSB5 : begin              // Receive Y MSB bit 5
                Y[13] <= miso;
                if (counter == 32'd172)
                    state_reg <= REC_YMSB4;
            end
            REC_YMSB4 : begin              // Receive Y MSB bit 4
                Y[12] <= miso;
                if (counter == 32'd176)
                    state_reg <= REC_YMSB3;
            end
            REC_YMSB3 : begin              // Receive Y MSB bit 3
                Y[11] <= miso;
                if (counter == 32'd180)
                    state_reg <= REC_YMSB2;
            end
            REC_YMSB2 : begin              // Receive Y MSB bit 2
                Y[10] <= miso;
                if (counter == 32'd184)
                    state_reg <= REC_YMSB1;
            end
            REC_YMSB1 : begin              // Receive Y MSB bit 1
                Y[9] <= miso;
                if (counter == 32'd188)
                    state_reg <= REC_YMSB0;
            end
            REC_YMSB0 : begin              // Receive Y MSB bit 0
                Y[8] <= miso;
                if (counter == 32'd192)
                    state_reg <= REC_ZLSB7;
            end

            REC_ZLSB7 : begin              // Receive Z LSB bit 7
                Z[7] <= miso;
                if (counter == 32'd196)
                    state_reg <= REC_ZLSB6;
            end
            REC_ZLSB6 : begin              // Receive Z LSB bit 6
                Z[6] <= miso;
                if (counter == 32'd200)
                    state_reg <= REC_ZLSB5;
            end
            REC_ZLSB5 : begin              // Receive Z LSB bit 5
                Z[5] <= miso;
                if (counter == 32'd204)
                    state_reg <= REC_ZLSB4;
            end
            REC_ZLSB4 : begin              // Receive Z LSB bit 4
                Z[4] <= miso;
                if (counter == 32'd208)
                    state_reg <= REC_ZLSB3;
            end
            REC_ZLSB3 : begin              // Receive Z LSB bit 3
                Z[3] <= miso;
                if (counter == 32'd212)
                    state_reg <= REC_ZLSB2;
            end
            REC_ZLSB2 : begin              // Receive Z LSB bit 2
                Z[2] <= miso;
                if (counter == 32'd216)
                    state_reg <= REC_ZLSB1;
            end
            REC_ZLSB1 : begin              // Receive Z LSB bit 1
                Z[1] <= miso;
                if (counter == 32'd220)
                    state_reg <= REC_ZLSB0;
            end
            REC_ZLSB0 : begin              // Receive Z LSB bit 0
                Z[0] <= miso;
                if (counter == 32'd224)
                    state_reg <= REC_ZMSB7;
            end

            REC_ZMSB7 : begin              // Receive Z MSB bit 7
                Z[15] <= miso;
                if (counter == 32'd228)
                    state_reg <= REC_ZMSB6;
            end
            REC_ZMSB6 : begin              // Receive Z MSB bit 6
                Z[14] <= miso;
                if (counter == 32'd232)
                    state_reg <= REC_ZMSB5;
            end
            REC_ZMSB5 : begin              // Receive Z MSB bit 5
                Z[13] <= miso;
                if (counter == 32'd236)
                    state_reg <= REC_ZMSB4;
            end
            REC_ZMSB4 : begin              // Receive Z MSB bit 4
                Z[12] <= miso;
                if (counter == 32'd240)
                    state_reg <= REC_ZMSB3;
            end
            REC_ZMSB3 : begin              // Receive Z MSB bit 3
                Z[11] <= miso;
                if (counter == 32'd244)
                    state_reg <= REC_ZMSB2;
            end
            REC_ZMSB2 : begin              // Receive Z MSB bit 2
                Z[10] <= miso;
                if (counter == 32'd248)
                    state_reg <= REC_ZMSB1;
            end
            REC_ZMSB1 : begin              // Receive Z MSB bit 1
                Z[9] <= miso;
                if (counter == 32'd252)
                    state_reg <= REC_ZMSB0;
            end
            REC_ZMSB0 : begin              // Receive Z MSB bit 0
                Z[8] <= miso;
                if (counter == 32'd256) begin
                    cs           <= 1'b1;    // Deactivate chip select
                    sclk_control <= 1'b0;    // Deactivate sclk
                    state_reg    <= END_SPI;
                end
            end

            END_SPI : begin                // End SPI read, wait 10ms
                if (counter == 32'd40259) begin
                    counter   <= 32'd0;     // Reset counter
                    state_reg <= BEGIN_SPIR; // Loop back to initiate another read
                end
            end
        endcase
    end

    // Data buffer logic triggered on negative edge of iclk
    always @(negedge iclk)
        if (latch_data) begin                    // Latch data 1.5 ticks after entering END_SPI
            temp_DATA <= {X[11:7], Y[11:7], Z[11:7]}; // Latch sign bit + 4 data bits per axis
        end

    // Output accelerometer data
    assign acl_data = temp_DATA;

    assign latch_data = ((state_reg == END_SPI) && (counter == 32'd258)) ? 1 : 0;
    assign sclk = (sclk_control) ? clk_reg : 0;

endmodule
