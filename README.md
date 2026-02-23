# Polar Code + CRC-16 ECC Subsystem

## Vivado xsim Commands
To compile and run the simulation using the provided testbench, use the following commands in the Vivado Tcl Console or a terminal with the Vivado environment set up:

```bash
# Compile all SystemVerilog files
xvlog -sv polar_common_pkg.sv crc.sv polar64_crc16_encoder.sv polar64_crc16_decoder.sv tb_basic.sv

# Elaborate the design (top-level: tb_basic)
xelab -debug typical tb_basic -s top_sim

# Run the simulation
xsim top_sim -R