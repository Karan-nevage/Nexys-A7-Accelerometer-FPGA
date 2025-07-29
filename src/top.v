`timescale 1ns / 1ps

module top (
    input  wire CLK100MHZ,            // Nexys A7 clock
    input  wire ACL_MISO,             // Master In Slave Out
    output wire ACL_MOSI,             // Master Out Slave In
    output wire ACL_SCLK,             // SPI clock
    output wire ACL_CSN,              // SPI chip select
    output wire [14:0] LED,           // LEDs for X[14:10], Y[9:5], Z[4:0]
    output wire [6:0] SEG,            // 7 segments of display
    output wire DP,                   // Decimal point of display
    output wire [7:0] AN              // 8 anodes for 7-segment display
);

    wire w_4MHz;                       // Internal 4 MHz clock wire
    wire [14:0] acl_data;              // Internal 15-bit accelerometer data wire

    // Instantiate clock generation module
    iclk_genr clock_generation (
        .CLK100MHZ(CLK100MHZ),
        .clk_4MHz(w_4MHz)
    );

    // Instantiate SPI master module
    spi_master master (
        .iclk(w_4MHz),
        .miso(ACL_MISO),
        .sclk(ACL_SCLK),
        .mosi(ACL_MOSI),
        .cs(ACL_CSN),
        .acl_data(acl_data)
    );

    // Instantiate 7-segment display control module
    seg7_control display_control (
        .CLK100MHZ(CLK100MHZ),
        .acl_data(acl_data),
        .seg(SEG),
        .dp(DP),
        .an(AN)
    );

    // Assign accelerometer data to LEDs
    assign LED[14:10] = acl_data[14:10];    // 5 bits of X data from 14 to 10
    assign LED[9:5]   = acl_data[9:5];      // 5 bits of Y data from 9 to 5
    assign LED[4:0]   = acl_data[4:0];      // 5 bits of Z data from 4 to 0

endmodule
