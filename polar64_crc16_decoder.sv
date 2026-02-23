`include "polar_common_pkg.sv"
import polar_common_pkg::*;

module polar64_crc16_decoder (
    input logic clk,
    input logic rst_n,
    input logic start,          // 1-cycle pulse
    input logic [63:0] rx,      // Received codeword
    output logic done,          // 1-cycle pulse, within 12 cycles
    output logic [23:0] data_out,
    output logic valid
);

    // CRC function
    function automatic logic [15:0] crc16_comb(input logic [23:0] data);
        logic [15:0] crc = 16'h0000;
        logic feedback;
        for (int i = 23; i >= 0; i--) begin
            feedback = data[i] ^ crc[15];
            crc = {crc[14:0], 1'b0};
            if (feedback) crc = crc ^ 16'h1021;
        end
        return crc;
    endfunction

    // Polar transform
    function automatic logic [63:0] polar_transform_comb(input logic [63:0] u);
        logic [63:0] v = u;
        for (int s = 0; s < 6; s++) begin
            int step = 2 << s;
            int half = 1 << s;
            for (int i = 0; i < 64; i += step) begin
                for (int j = 0; j < half; j++) begin
                    v[i+j] ^= v[i+j+half];
                end
            end
        end
        return v;
    endfunction

    // State machine
    typedef enum logic [2:0] {
        IDLE   = 3'd0,
        LOAD   = 3'd1,
        SC_W0  = 3'd2,
        SC_W1  = 3'd3,
        DECIDE = 3'd4,
        OUTPUT = 3'd5
    } state_t;

    state_t state;

    logic [63:0] rx_reg;
    logic [23:0] candidate_data;
    logic        candidate_valid;
    logic [1:0]  candidate_count;   // 0=none, 1=one, 2=multiple
    logic [3:0]  cycle_cnt;

    always_ff @(posedge clk or negedge rst_n) begin : main_fsm
        if (!rst_n) begin
            state           <= IDLE;
            rx_reg          <= 64'h0;
            candidate_data  <= 24'h0;
            candidate_valid <= 1'b0;
            candidate_count <= 2'd0;
            cycle_cnt       <= 4'd0;
            data_out        <= 24'h0;
            valid           <= 1'b0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        rx_reg          <= rx;
                        candidate_count <= 2'd0;
                        candidate_valid <= 1'b0;
                        cycle_cnt       <= 4'd0;
                        state           <= LOAD;
                    end
                end

                LOAD: begin
                    state     <= SC_W0;
                    cycle_cnt <= cycle_cnt + 1;
                end

                SC_W0: begin : sc_w0_block
                    logic [63:0] u_hat;
                    logic [63:0] u_frozen;
                    logic [23:0] d_extract;
                    logic [15:0] crc_extract;
                    logic        crc_ok;

                    u_hat = polar_transform_comb(rx_reg);
                    u_frozen = u_hat;

                    for (int i = 0; i < 64; i = i + 1) begin
                        if (!is_info_pos(i)) begin
                            u_frozen[i] = 1'b0;
                        end
                    end

                    d_extract   = 24'h0;
                    crc_extract = 16'h0;

                    for (int i = 0; i < 24; i = i + 1) begin
                        int pos = get_data_pos(i);
                        if (pos >= 0) begin
                            d_extract[23-i] = u_frozen[pos];
                        end
                    end

                    for (int i = 0; i < 16; i = i + 1) begin
                        int pos = get_crc_pos(i);
                        if (pos >= 0) begin
                            crc_extract[15-i] = u_frozen[pos];
                        end
                    end

                    crc_ok = (crc16_comb(d_extract) == crc_extract);

                    if (crc_ok) begin
                        candidate_data  <= d_extract;
                        candidate_valid <= 1'b1;
                        candidate_count <= 2'd1;
                    end

                    state     <= SC_W1;
                    cycle_cnt <= cycle_cnt + 1;
                end : sc_w0_block

                SC_W1: begin : sc_w1_block
                    logic [1:0]  local_count;
                    logic [23:0] local_best;
                    logic        local_valid;

                    local_count = candidate_count;
                    local_best  = candidate_data;
                    local_valid = candidate_valid;

                    for (int p = 0; p < 64; p = p + 1) begin
                        logic [63:0] r_flip;
                        logic [63:0] u_hat;
                        logic [63:0] u_frozen;
                        logic [23:0] d_extract;
                        logic [15:0] crc_extract;
                        logic        crc_ok;

                        r_flip = rx_reg ^ (64'd1 << p);
                        u_hat  = polar_transform_comb(r_flip);
                        u_frozen = u_hat;

                        for (int i = 0; i < 64; i = i + 1) begin
                            if (!is_info_pos(i)) begin
                                u_frozen[i] = 1'b0;
                            end
                        end

                        d_extract   = 24'h0;
                        crc_extract = 16'h0;

                        for (int i = 0; i < 24; i = i + 1) begin
                            int pos = get_data_pos(i);
                            if (pos >= 0) begin
                                d_extract[23-i] = u_frozen[pos];
                            end
                        end

                        for (int i = 0; i < 16; i = i + 1) begin
                            int pos = get_crc_pos(i);
                            if (pos >= 0) begin
                                crc_extract[15-i] = u_frozen[pos];
                            end
                        end

                        crc_ok = (crc16_comb(d_extract) == crc_extract);

                        if (crc_ok) begin
                            if (local_count == 2'd0) begin
                                local_count  = 2'd1;
                                local_best   = d_extract;
                                local_valid  = 1'b1;
                            end
                            else if (local_count == 2'd1) begin
                                local_count = 2'd2;
                            end
                        end
                    end

                    candidate_count <= local_count;
                    candidate_data  <= local_best;
                    candidate_valid <= local_valid;

                    state     <= DECIDE;
                    cycle_cnt <= cycle_cnt + 1;
                end : sc_w1_block

                DECIDE: begin
                    valid    <= (candidate_count == 2'd1) && candidate_valid;
                    data_out <= candidate_data;
                    done     <= 1'b1;
                    state    <= OUTPUT;
                    cycle_cnt <= cycle_cnt + 1;
                end

                OUTPUT: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end : main_fsm

endmodule
