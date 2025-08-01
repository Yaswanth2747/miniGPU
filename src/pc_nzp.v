// pc_nzp.v
// Program Counter (PC) and NZP Flags module for a single miniGPU thread.
// Manages the address of the next instruction to fetch and the condition flags
// (Negative, Zero, Positive) used for conditional branching.

module pc_nzp ( // Module name is lowercase: pc_nzp
    input clk,                         // Clock signal
    input reset,                       // Asynchronous reset signal
    input enable,                      // Enable signal for this pc_nzp instance (from core)
    input [2:0] core_state,            // Current pipeline state from Scheduler (e.g., 3'b101=EXECUTE, 3'b110=UPDATE)

    input [7:0] current_pc,            // Input: The PC value from the Fetcher (which is current_pc[0] in Fetcher)
                                       // This is effectively the PC from the FETCH stage.

    input [7:0] alu_out,               // Input: Result from the alu (specifically for NZP flag updates).
                                       // alu's CMP output packs N, Z, P into bits [2:0] respectively.

    input [7:0] imm8,                  // Input: 8-bit immediate value, typically from Decoder for branch target address.

    input [2:0] decoded_nzp,           // Input: 3-bit decoded NZP condition from Decoder for branch instructions.
                                       // Format: {N_cond, Z_cond, P_cond} - 1 means condition must be met.

    input nzp_write_enable,            // Control: 1 if NZP flags should be updated (e.g., after CMP instruction).

    input next_pc_mux,                 // Control: PC multiplexer select signal from Decoder.
                                       //   0: next_pc = current_pc + 1 (sequential execution)
                                       //   1: next_pc = imm8 (branch target)

    output reg [7:0] next_pc,          // Output: The calculated next PC value (to Fetcher for next instruction).
    output reg [2:0] nzp_flags         // Output: The current Negative, Zero, Positive flags (3 bits).
);

    // Main sequential logic for PC and NZP flag updates.
    always @(posedge clk or posedge reset) begin : pc_nzp_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // On reset, initialize PC to 0 and clear NZP flags.
            next_pc <= 8'b0;      // Start execution from address 0
            nzp_flags <= 3'b0;    // Clear all flags (N=0, Z=0, P=0)
        end else if (enable) begin // Only operate if the pc_nzp unit is enabled by the core
            // ==========================================================
            // PC Update Logic (Occurs in the EXECUTE stage)
            // ==========================================================
            if (core_state == 3'b101) begin // If in the EXECUTE state of the pipeline
                // Check if branching is enabled (next_pc_mux == 1)
                // AND if the current NZP flags meet the decoded branch condition.
                // (nzp_flags & decoded_nzp) != 3'b0 means at least one of the
                // required conditions (N, Z, or P) is true in both the current flags and the decoded mask.
                if (next_pc_mux && ((nzp_flags & decoded_nzp) != 3'b0)) begin
                    // Conditional Branch: Update PC to the immediate target address.
                    next_pc <= imm8;
                end else begin
                    // Sequential Execution: Increment PC to the next instruction.
                    next_pc <= current_pc + 1;
                end
            end

            // ==========================================================
            // NZP Flag Update Logic (Occurs in the UPDATE stage)
            // ==========================================================
            if (core_state == 3'b110 && nzp_write_enable) begin // If in UPDATE state AND NZP update is enabled
                // Latch the lower 3 bits of the alu output as the new NZP flags.
                // alu's CMP operation would have packed these flags into alu_out[2:0].
                nzp_flags <= alu_out[2:0];
            end
        end
    end

endmodule
