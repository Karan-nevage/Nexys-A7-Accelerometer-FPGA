# Nexys-A7-Accelerometer-FPGA

This project demonstrates the integration of the inbuilt 3-axis accelerometer (ADXL362) on the Nexys A7-50T FPGA board. The accelerometer data is read using SPI communication and visualized through 7-segment displays and LEDs. The Verilog-based design handles SPI communication, data processing, and display control, providing a practical example of FPGA-based sensor interfacing.

## Overview

The project implements a system where:
- The ADXL362 accelerometer, inbuilt on the Nexys A7-50T board, provides 3-axis acceleration data (X, Y, Z).
- SPI communication is used to interface with the inbuilt accelerometer.
- The data is processed and displayed on:
  - A 7-segment display showing the acceleration values for each axis.
  - LEDs indicating the raw 5-bit data for each axis.
- The Nexys A7-50T FPGA board serves as the hardware platform, utilizing its 100 MHz clock and I/O capabilities.

## Features

- **SPI Master Implementation**: Manages communication with the inbuilt ADXL362 accelerometer at 4 MHz, with a derived 1 MHz SPI clock.
- **Clock Generation**: Generates a 4 MHz clock from the 100 MHz system clock for internal use.
- **Data Processing**: Extracts and converts 6-bit accelerometer data into BCD format for 7-segment display.
- **Display Control**: Drives an 8-digit 7-segment display to show X, Y, and Z axis values, with decimal points indicating negative values.
- **LED Feedback**: Maps 15-bit accelerometer data (5 bits per axis) to 15 LEDs for real-time status.

## Hardware Requirements

- **Nexys A7-50T FPGA Board**: Includes the inbuilt 100 MHz clock, LEDs, 7-segment display, and ADXL362 accelerometer.
- **Development Tools**: Xilinx Vivado (or compatible) for synthesis and implementation.

## Project Structure

- **`iclk_genr.v`**: Verilog module to generate a 4 MHz clock from the 100 MHz system clock.
- **`seg7_control.v`**: Verilog module to control the 7-segment display, converting accelerometer data to BCD and driving the display anodes.
- **`spi_master.v`**: Verilog module implementing the SPI master to communicate with the inbuilt ADXL362 and retrieve 15-bit accelerometer data.
- **`top.v`**: Top-level Verilog module integrating all sub-modules and connecting to FPGA I/O ports.
- **`assigned.xdc`**: Constraint file mapping FPGA pins to the Nexys A7-50T board I/O (e.g., clock, LEDs, 7-segment display, SPI signals).

## Signal Table

| Signal Name  | Description                              | Direction | Port Mapping (Nexys A7-50T) |
|--------------|------------------------------------------|-----------|-----------------------------|
| `CLK100MHZ`  | 100 MHz system clock                    | Input     | E3                          |
| `LED[14:0]`  | 15 LEDs for raw 5-bit data per axis     | Output    | H17, K15, J13, N14, R18, V17, U17, U16, V16, T15, U14, T16, V15, V14, V12 |
| `SEG[6:0]`   | 7-segment display segments              | Output    | T10, R10, K16, K13, P15, T11, L18 |
| `DP`         | Decimal point for 7-segment display     | Output    | H15                        |
| `AN[7:0]`    | 8 anode signals for 7-segment display   | Output    | J17, J18, T9, J14, P14, T14, K2, U13 |
| `ACL_MISO`   | Master In Slave Out (SPI)               | Input     | E15                        |
| `ACL_MOSI`   | Master Out Slave In (SPI)               | Output    | F14                        |
| `ACL_SCLK`   | SPI clock                               | Output    | F15                        |
| `ACL_CSN`    | SPI chip select (active low)            | Output    | D15                        |

## Setup Instructions

1. **Install Vivado**: Ensure Xilinx Vivado is installed with support for the Nexys A7-50T board.
2. **Clone the Repository**: Download or clone this project to your local machine.
3. **Create a New Project**:
   - Open Vivado and create a new project.
   - Select the Nexys A7-50T as the target board.
4. **Add Source Files**:
   - Import `iclk_genr.v`, `seg7_control.v`, `spi_master.v`, and `top.v` as Verilog source files.
   - Import `assigned.xdc` as the constraint file.
5. **Synthesize and Implement**:
   - Run synthesis and implementation in Vivado.
   - Generate the bitstream file.
6. **Program the FPGA**:
   - Connect the Nexys A7-50T board via USB.
   - Use Vivado's hardware manager to program the FPGA with the generated bitstream.
7. **Verify**:
   - Tilt or move the board to observe changes in the 7-segment display and LEDs, reflecting the inbuilt accelerometer data.

## Usage

- **Power On**: Ensure the Nexys A7-50T is powered on.
- **Observation**: The 7-segment display will show the acceleration values for X, Y, and Z axes (tens and ones digits), with the decimal point lit for negative values. The LEDs will display the raw 5-bit data for each axis.
- **Interaction**: Move the board to see real-time updates from the inbuilt accelerometer.

## Limitations

- The current design uses only 4 bits of the 6-bit accelerometer data for display, limiting the range.
- The SPI communication assumes a specific timing and may need adjustment for optimal performance with the inbuilt ADXL362.
- LED[15] and accelerometer interrupt pins are not utilized.

## Contributing

Contributions are welcome! Please fork the repository and submit pull requests with improvements, such as:
- Enhanced data precision for the 7-segment display.
- Additional features like interrupt handling for the inbuilt accelerometer.
- Optimization of SPI timing or clock generation.

## License

This project is released under the MIT License. See the `LICENSE` file for details.

## Acknowledgments

- Thanks Dr.Malode, Professor at MGM's JNEC, Chh. Sambhaji Nagar, Maharahtra. 
- Thanks to Digilent for the Nexys A7-50T board documentation and inbuilt ADXL362 accelerometer.
- Inspired by FPGA-based sensor projects and the ADXL362 datasheet.


## Author Details

- **Name**: Karankumar Nevage  || Ayush Lakade
- **Email**: karanpr9423@gmail.com
- **LinkedIn**: [linkedin.com/in/karankumar-nevage](https://www.linkedin.com/in/karankumar-nevage/) 


## Release Information

- **Date**: Nov, 2024
- **License**: MIT License
