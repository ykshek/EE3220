`include "polar_common_pkg.sv"
import polar_common_pkg::*;

module polar64_crc16_encoder (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,          // 1-cycle pulse
    input  logic [23:0] data_in,        // 24-bit data input
    output logic        done,           // 1-cycle pulse, 2 cycles after start
    output logic [63:0] codeword        // 64-bit encoded codeword
);
    
    // ------------------------------------------------------------------------
    // ???????CRC-16-CCITT ??
    // ------------------------------------------------------------------------
    function automatic logic [15:0] crc16_comb(input logic [23:0] data);
        logic [15:0] crc;
        logic feedback;
        
        crc = 16'h0000;
        
        for (int i = 23; i >= 0; i--) begin
            feedback = data[i] ^ crc[15];
            crc = {crc[14:0], 1'b0};
            if (feedback) begin
                crc = crc ^ 16'h1021;
            end
        end
        
        return crc;
    endfunction
    
    // ------------------------------------------------------------------------
    // ????????? u_vector
    // ------------------------------------------------------------------------
    function automatic logic [63:0] build_u_comb(
        input logic [23:0] data,
        input logic [15:0] crc
    );
        logic [63:0] u;
        u = 64'd0;
        
        for (int i = 0; i < DATA_BITS; i++) begin
            int pos = get_data_pos(i);
            if (pos >= 0) begin
                u[pos] = data[DATA_BITS-1-i];
            end
        end
        
        for (int i = 0; i < CRC_BITS; i++) begin
            int pos = get_crc_pos(i);
            if (pos >= 0) begin
                u[pos] = crc[CRC_BITS-1-i];
            end
        end
        
        return u;
    endfunction
    
    // ------------------------------------------------------------------------
    // ???????Polar ??
    // ------------------------------------------------------------------------
    function automatic logic [63:0] polar_transform_comb(input logic [63:0] u);
        logic [63:0] v;
        v = u;
        
        for (int s = 0; s < 6; s++) begin
            int step = 2 << s;
            int half = 1 << s;
            
            for (int i = 0; i < 64; i += step) begin
                for (int j = 0; j < half; j++) begin
                    v[i+j] = v[i+j] ^ v[i+j+half];
                end
            end
        end
        
        return v;
    endfunction
    
    // ------------------------------------------------------------------------
    // ?????
    // ------------------------------------------------------------------------
    logic [63:0] u_reg;
    logic [63:0] codeword_reg;
    logic [1:0]  cycle_count;
    logic        start_d1;
    logic        start_d2;
    
    // ------------------------------------------------------------------------
    // ???????? CRC ? u_vector
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_reg <= 64'd0;
        end else if (start) begin
            u_reg <= build_u_comb(data_in, crc16_comb(data_in));
        end
    end
    
    // ------------------------------------------------------------------------
    // ???????? Polar ??
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            codeword_reg <= 64'd0;
        end else begin
            codeword_reg <= polar_transform_comb(u_reg);
        end
    end
    
    // ------------------------------------------------------------------------
    // ????? done ????
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 2'd0;
            start_d1 <= 1'b0;
            start_d2 <= 1'b0;
            done <= 1'b0;
        end else begin
            // ?? start ??
            start_d1 <= start;
            start_d2 <= start_d1;
            
            // ????
            if (start) begin
                cycle_count <= 2'd1;
            end else if (cycle_count == 2'd1) begin
                cycle_count <= 2'd2;
            end else if (cycle_count == 2'd2) begin
                cycle_count <= 2'd0;
            end
            
            // done ? start ?? 2 ?????
            if (cycle_count == 2'd1 && start_d1) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    // ------------------------------------------------------------------------
    // ????
    // ------------------------------------------------------------------------
    assign codeword = codeword_reg;
    
endmodule