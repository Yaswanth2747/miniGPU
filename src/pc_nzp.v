module PC_NZP (
    input clk, reset, enable,
    input [2:0] core_state,    // From scheduler (101=EXECUTE, 110=UPDATE)
    input [7:0] current_pc,    // Current PC value
    input [7:0] alu_out,       // From thread's ALU for NZP updates
    input [7:0] imm8,          // Immediate address for BRnzp
    input [2:0] decoded_nzp,   // NZP condition for BRnzp
    input nzp_write_enable,    // Enables NZP update
    input next_pc_mux,         // 0 = PC+1, 1 = Branch
    output reg [7:0] next_pc,  // Updated PC
    output reg [2:0] nzp_flags // N, Z, P flags
);
    always @(posedge clk) begin
        if (reset) begin
            next_pc <= 8'b0;
            nzp_flags <= 3'b0;
        end else if (enable) begin
            // EXECUTE state: Update PC
            if (core_state == 3'b101) begin
                if (next_pc_mux && (nzp_flags & decoded_nzp) != 3'b0) begin
                    // Branches if NZP matches condition
                    next_pc <= imm8;
                end else begin
                    // Sequential execution
                    next_pc <= current_pc + 1;
                end
            end
            // UPDATE state: Update NZP flags
            if (core_state == 3'b110 && nzp_write_enable) begin
                nzp_flags <= alu_out[2:0]; // N, Z, P from ALU
            end
        end
    end
endmodule
