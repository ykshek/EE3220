module crc16 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,      // Start CRC computation
    input  logic [23:0] data_in,    // 24-bit data input
    input  logic        data_valid, // Data valid signal
    output logic [15:0] crc_out,    // 16-bit CRC result
    output logic        crc_done     // CRC computation done
);
    
    // Internal registers
    logic [15:0] crc_reg;
    logic [4:0]  bit_count;
    logic [23:0] data_reg;
    logic        busy;
    
    // CRC constant (without x^16 term)
    localparam CRC_POLY = 16'h1021;
    
    // State machine states
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (bit_count == 5'd23) next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // CRC computation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 16'h0000;
            bit_count <= 5'd0;
            data_reg <= 24'd0;
            busy <= 1'b0;
            crc_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        data_reg <= data_in;
                        crc_reg <= 16'h0000;  // Initial value
                        bit_count <= 5'd0;
                        busy <= 1'b1;
                        crc_done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    // MSB-first processing (data_in[23] down to data_in[0])
                    logic feedback;
                    logic [15:0] crc_next;
                    
                    // feedback = data bit XOR MSB of CRC
                    feedback = data_reg[23] ^ crc_reg[15];
                    
                    // Shift CRC left by 1
                    crc_next = {crc_reg[14:0], 1'b0};
                    
                    // Apply feedback if needed
                    if (feedback) begin
                        crc_next = crc_next ^ CRC_POLY;
                    end
                    
                    crc_reg <= crc_next & 16'hFFFF;
                    data_reg <= {data_reg[22:0], 1'b0};  // Shift data left
                    bit_count <= bit_count + 1;
                end
                
                DONE: begin
                    crc_done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    assign crc_out = crc_reg;
    
endmodule
