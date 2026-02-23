`include "polar_common_pkg.sv"
import polar_common_pkg::*;

module polar64_crc16_decoder (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,          // 1-cycle pulse
    input  logic [63:0] rx,             // Received codeword (possibly with errors)
    output logic        done,           // 1-cycle pulse, within 12 cycles
    output logic [23:0] data_out,       // Decoded data
    output logic        valid           // Valid flag (fail-safe)
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
    // ?????????????
    // ------------------------------------------------------------------------
    function automatic logic [2:0] hamming_distance(input logic [63:0] a, b);
        logic [2:0] hamming_val;
        hamming_val = 3'd0;
        for (int i = 0; i < 64; i++) begin
            if (a[i] != b[i]) begin
                hamming_val = hamming_val + 1;
            end
        end
        return hamming_val;
    endfunction
    
    // ------------------------------------------------------------------------
    // ???? - ???????????????
    // ------------------------------------------------------------------------
    // ???????
    logic [63:0] u_hat_reg;
    logic [23:0] data_out_reg;
    logic [15:0] crc_extracted_reg;
    logic [15:0] crc_calc_reg;
    logic [63:0] reencoded_reg;
    logic [2:0]  hamming_val_reg;
    logic        distance_ok_reg;
    logic        crc_ok_reg;
    
    // ????
    logic [3:0]  cycle_count;
    logic        decoding_active;
    logic        result_valid;
    logic [23:0] result_data;
    
    // ------------------------------------------------------------------------
    // ???? - ?? always_ff ????????
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_hat_reg <= 64'd0;
            data_out_reg <= 24'd0;
            crc_extracted_reg <= 16'd0;
            crc_calc_reg <= 16'd0;
            reencoded_reg <= 64'd0;
            hamming_val_reg <= 3'd0;
            distance_ok_reg <= 1'b0;
            crc_ok_reg <= 1'b0;
        end else if (start || decoding_active) begin
            // ????
            logic [63:0] u_hat;
            logic [23:0] data_out_int;
            logic [15:0] crc_extracted;
            logic [63:0] reencoded;
            logic [2:0]  hamming_val;
            logic [15:0] crc_calc;
            
            // 1. ??? u_hat
            u_hat = 64'd0;
            
            // 2. ???????????
            for (int i = 0; i < 64; i++) begin
                if (is_info_pos(i)) begin
                    u_hat[i] = rx[i];
                end
            end
            
            // 3. ??????
            for (int i = 0; i < 24; i++) begin
                int pos = get_data_pos(i);
                if (pos >= 0) begin
                    data_out_int[23-i] = u_hat[pos];
                end
            end
            
            // 4. ?? CRC ??
            for (int i = 0; i < 16; i++) begin
                int pos = get_crc_pos(i);
                if (pos >= 0) begin
                    crc_extracted[15-i] = u_hat[pos];
                end
            end
            
            // 5. ????
            reencoded = polar_transform_comb(u_hat);
            
            // 6. ??????
            hamming_val = hamming_distance(reencoded, rx);
            
            // 7. ?? CRC
            crc_calc = crc16_comb(data_out_int);
            
            // 8. ??????
            u_hat_reg <= u_hat;
            data_out_reg <= data_out_int;
            crc_extracted_reg <= crc_extracted;
            reencoded_reg <= reencoded;
            hamming_val_reg <= hamming_val;
            crc_calc_reg <= crc_calc;
            
            // 9. ????
            distance_ok_reg <= (hamming_val <= 3);
            crc_ok_reg <= (crc16_comb(data_out_int) == crc_extracted);
        end
    end
    
    // ------------------------------------------------------------------------
    // ???? - ?? always_ff ??
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
            decoding_active <= 1'b0;
            done <= 1'b0;
            data_out <= 24'd0;
            valid <= 1'b0;
            result_data <= 24'd0;
            result_valid <= 1'b0;
        end else begin
            // ???
            done <= 1'b0;
            
            // ????
            if (start) begin
                // ?? start?????
                cycle_count <= 4'd1;
                decoding_active <= 1'b1;
                result_valid <= 1'b0;
            end else if (decoding_active) begin
                // ?????
                cycle_count <= cycle_count + 1;
                
                // ???????????
                case (cycle_count)
                    4'd1: begin
                        // ?1?????????
                    end
                    
                    4'd2: begin
                        // ?2???????
                        result_data <= data_out_reg;
                        result_valid <= (distance_ok_reg && crc_ok_reg);
                    end
                    
                    4'd3: begin
                        // ?3???????
                        data_out <= result_data;
                        valid <= result_valid;
                        done <= 1'b1;
                        decoding_active <= 1'b0;
                    end
                    
                    default: begin
                        // ????
                        if (cycle_count >= 4'd11) begin
                            data_out <= 24'd0;
                            valid <= 1'b0;
                            done <= 1'b1;
                            decoding_active <= 1'b0;
                        end
                    end
                endcase
            end
            
            // ???? start ??? decoding_active?????????
            if (!start && !decoding_active) begin
                data_out <= 24'd0;
                valid <= 1'b0;
            end
        end
    end
    
    // ------------------------------------------------------------------------
    // ???????
    // ------------------------------------------------------------------------
    // synthesis translate_off
    always @(posedge clk) begin
        if (start) begin
            $display("DECODER: start received at time %t, rx=%h", $time, rx);
        end
        if (done) begin
            $display("DECODER: done at time %t, data_out=%h, valid=%b, distance=%d, crc_match=%b", 
                     $time, data_out, valid, hamming_val_reg, crc_ok_reg);
        end
        if ($isunknown(data_out) || $isunknown(valid)) begin
            $display("DECODER WARNING: X detected on outputs at time %t", $time);
        end
    end
    
    // ?? done ???12???
    always @(posedge clk) begin
        if (start) begin
            assert property (@(posedge clk) 
                ##[1:12] done == 1'b1
            ) else $error("Decoder ERROR: done not asserted within 12 cycles at time %t", $time);
        end
    end
    // synthesis translate_on
    
endmodule