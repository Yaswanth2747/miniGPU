module alu (
    input clk, reset, enable,
    input [2:0] core_state,
    input [1:0] decoded_alu_arithmetic_mux,
    input decoded_alu_output_mux,
    input [7:0] rs, rt,
    output reg [7:0] alu_out
);
    reg [7:0] internal_reg;
    
    always @(posedge clk) begin
        if (reset) begin
            alu_out <= 8'b0;
        end else if (enable && core_state == 3'b101) begin
            if (decoded_alu_output_mux) begin
                // NZP flags for CMP instruction
                internal_reg[7:3] = 5'b0;
                internal_reg[2] = (rs < rt);   // N (negative)
                internal_reg[1] = (rs == rt);  // Z (zero)
                internal_reg[0] = (rs > rt);   // P (positive)
            end else begin
                // arithmetic operation operations
                case (decoded_alu_arithmetic_mux)
                    2'b00: internal_reg = rs + rt;                       // ADD
                    2'b01: internal_reg = rs - rt;                       // SUB
                    2'b10: internal_reg = rs * rt;                       // MUL (lower 8 bits)
                    2'b11: internal_reg = (rt != 0) ? rs / rt : 8'b0;    // DIV (handle divide-by-zero)
                endcase
            end
            alu_out <= internal_reg;
        end
    end
endmodule
