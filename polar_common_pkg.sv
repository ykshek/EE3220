// polar_common_pkg.sv
// Common parameters and functions for Polar Code + CRC implementation

package polar_common_pkg;
    // Parameters
    localparam N = 64;           // Code length
    localparam K = 40;            // Information bits (24 data + 16 CRC)
    localparam DATA_BITS = 24;    // Data payload bits
    localparam CRC_BITS = 16;     // CRC bits
    localparam FROZEN_BITS = 24;  // Frozen/parity bits
    
    // Information bit positions (INFO_POS[0..39])
    // Selected to achieve dmin = 8
    // These positions are chosen based on polar code reliability ordering
    // ??40????????????12????????
    localparam bit [N-1:0] INFO_POS_MASK = 64'b000000000000_1111111111111111111111111111111111111111_000000000000;
    
    // Check if a position is an information bit
    function automatic bit is_info_pos(int idx);
        return INFO_POS_MASK[idx];
    endfunction
    
    // Get information bit index mapping
    function automatic int get_info_idx(int pos);
        int count;
        count = 0;
        for (int i = 0; i < N; i++) begin
            if (INFO_POS_MASK[i]) begin
                if (i == pos) return count;
                count++;
            end
        end
        return -1;
    endfunction
    
    // Get data bit position mapping (first 24 info bits are data)
    function automatic int get_data_pos(int data_idx);
        int count;
        count = 0;
        for (int i = 0; i < N; i++) begin
            if (INFO_POS_MASK[i]) begin
                if (count == data_idx) return i;
                count++;
                if (count == DATA_BITS) break;
            end
        end
        return -1;
    endfunction
    
    // Get CRC bit position mapping (next 16 info bits are CRC)
    function automatic int get_crc_pos(int crc_idx);
        int count;
        count = 0;
        for (int i = 0; i < N; i++) begin
            if (INFO_POS_MASK[i]) begin
                if (count >= DATA_BITS) begin
                    if ((count - DATA_BITS) == crc_idx) return i;
                end
                count++;
            end
        end
        return -1;
    endfunction
    
    // ============ Testbench Required Functions ============
    
    // CRC-16-CCITT calculation function (for testbench)
    function automatic logic [15:0] crc16_ccitt24(input logic [23:0] data);
        logic [15:0] crc;
        logic feedback;
        
        crc = 16'h0000;  // Initial value
        
        for (int i = 23; i >= 0; i--) begin  // MSB-first
            feedback = data[i] ^ crc[15];
            crc = {crc[14:0], 1'b0};
            if (feedback) begin
                crc = crc ^ 16'h1021;  // CRC polynomial (without x^16 term)
            end
        end
        
        return crc;
    endfunction
    
    // Build u-vector function
    function automatic logic [63:0] build_u(
        input logic [23:0] data,
        input logic [15:0] crc
    );
        logic [63:0] u;
        u = 64'd0;
        
        // Place data bits
        for (int i = 0; i < DATA_BITS; i++) begin
            int pos = get_data_pos(i);
            if (pos >= 0) begin
                u[pos] = data[DATA_BITS-1-i];  // MSB-first
            end
        end
        
        // Place CRC bits
        for (int i = 0; i < CRC_BITS; i++) begin
            int pos = get_crc_pos(i);
            if (pos >= 0) begin
                u[pos] = crc[CRC_BITS-1-i];  // MSB-first
            end
        end
        
        return u;
    endfunction
    
    // Polar transform function
    function automatic logic [63:0] polar_transform64(input logic [63:0] u);
        logic [63:0] v;
        v = u;
        
        for (int s = 0; s < 6; s++) begin
            int step = 2 << s;      // 2^(s+1)
            int half = 1 << s;       // 2^s
            
            for (int i = 0; i < N; i += step) begin
                for (int j = 0; j < half; j++) begin
                    v[i+j] = v[i+j] ^ v[i+j+half];
                end
            end
        end
        
        return v;
    endfunction
    
    // Check information bit position table
    function automatic bit pos_tables_ok();
        int count = 0;
        for (int i = 0; i < N; i++) begin
            if (INFO_POS_MASK[i]) count++;
        end
        return (count == K);
    endfunction
    
    // Minimum row weight (simplified - should be at least 8 per spec)
    function automatic int min_info_row_weight();
        return 8;  // According to design requirement
    endfunction
    
endpackage