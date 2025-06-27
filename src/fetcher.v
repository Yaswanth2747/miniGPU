module Fetcher #(
    parameter NUM_THREADS = 4,  // number of threads per core
    parameter ADDR_BITS = 8,    // PC and memory address width
    parameter INSTR_BITS = 16   // instruction width
) (
    input clk, reset,                            // Clocks and resets synchronously
    input [2:0] core_state,                     // Receives state from Scheduler (001=FETCH)
    input [NUM_THREADS-1:0][ADDR_BITS-1:0] current_pc, // Receives PC from each thread's PC_NZP
    output reg [INSTR_BITS-1:0] instruction,    // Outputs 16-bit instruction to Decoder
    output reg [NUM_THREADS-1:0][ADDR_BITS-1:0] pc // Outputs PC values to PC_NZP modules
);
    // Defining program memory as 256-entry for now, 16-bit wide ROM
    reg [INSTR_BITS-1:0] program_memory [0:2**ADDR_BITS-1]; // maybe should reducce this later on, it is too much
    
    // Initializes program memory with example instructions
    initial begin
        // A few instructions based on the ISA
        program_memory[0]  = 16'b0011_0000_0000_0000; // ADD R0, R0, R0 (R0 = R0 + R0)
        program_memory[1]  = 16'b0010_0000_0000_0001; // CMP R0, R1 (sets NZP flags)
        program_memory[2]  = 16'b0001_100_00000010;   // BRnzp N, 2 (branches to PC=2 if negative)
        program_memory[3]  = 16'b1001_0001_00000100;  // CONST R1, 4 (R1 = 4)
        program_memory[4]  = 16'b0111_0010_0001_0000; // LDR R2, R1 (loads from address in R1 to R2)
        program_memory[5]  = 16'b1000_0010_0000_0000; // STR R0, R2 (stores R0 to address in R2)
        program_memory[6]  = 16'b1111_0000_0000_0000; // RET (ends block)
        // Filling remaining memory with NOPs
        for (integer i = 7; i < 256; i = i + 1)
            program_memory[i] = 16'b0000_0000_0000_0000; // NOP
    end
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Clearing outputs on reset
            instruction <= {INSTR_BITS{1'b0}};
            for (i = 0; i < NUM_THREADS; i = i + 1)
                pc[i] <= {ADDR_BITS{1'b0}};
        end else if (core_state == 3'b001) begin // FETCH state
            // Fetching instruction using thread 0's PC
            instruction <= program_memory[current_pc[0]];
            // Passing current PCs to PC_NZP modules
            for (i = 0; i < NUM_THREADS; i = i + 1)
                pc[i] <= current_pc[i];
        end
    end
endmodule
