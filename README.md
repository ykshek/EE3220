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
```

## Module descriptions and latency behavior
`crc16.sv`: Shared code used by both encoder and decoder.

`polar64_crc16_decoder.sv`: Returns a decoded codeword and assert done at the 5th clock after triggering

`polar64_crc16_encoder.sv`: Returns an encoded codeword and assert done at the 2nd clock after triggering


## Division of labour
Shek Yun Kwan(58532418) :   Verification, Debugging, readme.md

Yeung Hoi Ching(58533440) : Prompt Engineering, Debugging

Wong Ka Lung(58542922) :    Prompt Engineering, ai_log.txt

Hui Ka Yuet (58533415) :    Prompt Engineering, report.pdf, readme.md

Lau Chun Yin (58542239) :   Prompt Engineering, report.pdf

Cheng Ki Leong(55874161) :  Prompt Engineering, Verification
