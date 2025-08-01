// decoder.v
// Instruction Decoder for a single miniGPU core.
// Parses the 16-bit instruction and generates control signals for other pipeline stages.

module decoder ( // Module name is lowercase: decoder
    input clk,                           // Clock signal (for synchronous operation of output registers)
    input reset,                         // Asynchronous reset signal
    input [2:0] core_state,              // Current pipeline state from Scheduler (e.g., 3'b010 = DECODE)
    input [15:0] instruction,            // 16-bit instruction word from the Fetcher

    // Outputs for Register File
    output reg [3:0] rd_addr,            // Destination Register address
    output reg [3:0] rs_addr,            // Source Register 1 address
    output reg [3:0] rt_addr,            // Source Register 2 address / Data to store register address

    // Outputs for pc_nzp Unit
    output reg [7:0] imm8,               // 8-bit immediate value (for CONST or branch target)
    output reg [2:0] decoded_nzp,        // Decoded NZP condition for branch (N, Z, P mask - 3 bits)
    output reg nzp_write_enable,         // Enable signal for pc_nzp to update NZP flags

    // Outputs for Register File / alu / lsu control
    output reg reg_write_enable,         // Enable signal for Register File write
    output reg [1:0] reg_input_mux,      // Mux select for Register File write data:
                                         //   2'b00: alu output
                                         //   2'b01: lsu output (read data)
                                         //   2'b10: Immediate value

    // Outputs for lsu (Load/Store Unit) control
    output reg mem_read_enable,          // Enable signal for lsu to perform a memory read (LDR)
    output reg mem_write_enable,         // Enable signal for lsu to perform a memory write (STR)

    // Outputs for alu (Arithmetic Logic Unit) control
    output reg [1:0] alu_control,        // alu operation select:
                                         //   2'b00: ADD
                                         //   2'b01: SUB
                                         //   2'b10: MUL
                                         //   2'b11: DIV
    output reg alu_output_mux,           // alu output select for CMP:
                                         //   0: alu result for register write-back
                                         //   1: NZP flags for pc_nzp (for CMP instruction)

    // Outputs for pc_nzp Unit (for PC update)
    output reg next_pc_mux,              // PC select mux:
                                         //   0: PC + 1 (sequential)
                                         //   1: Branch target (imm8)
    output reg decoded_ret               // Signal to Scheduler: 1 if current instruction is RET
);

    // Instruction Field Extraction (Wires for combinatorial parsing)
    wire [3:0] opcode = instruction[15:12]; // Opcode: Bits 15 down to 12.
    wire [3:0] rd = instruction[11:8];      // Rd (Destination Register): Bits 11 down to 8.
    wire [3:0] rs = instruction[7:4];       // Rs (Source Register 1): Bits 7 down to 4.
    wire [3:0] rt = instruction[3:0];       // Rt (Source Register 2 / Store Data Register): Bits 3 down to 0.
    wire [2:0] nzp = instruction[10:8];     // NZP (Branch Condition): Bits 10 down to 8 (part of opcode field for BR).
    wire [7:0] imm = instruction[7:0];      // Imm (Immediate Value): Bits 7 down to 0.


    // Sequential Logic for Decoder:
    // All output control signals are registered. They are updated on the positive
    // edge of the clock when the core is in the DECODE state.
    always @(posedge clk or posedge reset) begin : decoder_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // On reset, clear all control outputs to their default (inactive/safe) states.
            rd_addr <= 4'b0;
            rs_addr <= 4'b0;
            rt_addr <= 4'b0;
            imm8 <= 8'b0;
            decoded_nzp <= 3'b0;
            reg_write_enable <= 1'b0;
            mem_read_enable <= 1'b0;
            mem_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            alu_control <= 2'b0;
            alu_output_mux <= 1'b0;
            reg_input_mux <= 2'b0;
            next_pc_mux <= 1'b0;
            decoded_ret <= 1'b0;
        end else if (core_state == 3'b010) begin // Only decode if in the DECODE state
            // Default: Clear all signals at the start of each decode cycle,
            // then set only those relevant to the current instruction.
            reg_write_enable <= 1'b0;
            mem_read_enable <= 1'b0;
            mem_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            alu_control <= 2'b0;
            alu_output_mux <= 1'b0;
            reg_input_mux <= 2'b0;
            next_pc_mux <= 1'b0;
            decoded_ret <= 1'b0;

            // Latch instruction fields: These are directly from the instruction bits.
            rd_addr <= rd;
            rs_addr <= rs;
            rt_addr <= rt;
            imm8 <= imm;
            decoded_nzp <= nzp;


            // Decode logic based on Opcode:
            case (opcode)
                4'b0000: begin // NOP
                    // No control signals asserted, all remain at default 0.
                end

                4'b0001: begin // BR (Branch)
                    next_pc_mux <= 1'b1; // Select branch target for PC update
                end

                4'b0010: begin // CMP (Compare)
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b01;      // ALU performs subtraction for comparison
                    alu_output_mux <= 1'b1;     // ALU outputs NZP flags
                    nzp_write_enable <= 1'b1;   // Enable pc_nzp to latch new NZP flags
                end

                4'b0011: begin // ADD
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b00;      // ALU performs ADD
                    alu_output_mux <= 1'b0;     // ALU outputs data
                    reg_write_enable <= 1'b1;   // Enable Register File write
                    reg_input_mux <= 2'b00;     // Data comes from ALU output
                end

                4'b0100: begin // SUB
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b01;      // ALU performs SUB
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00;
                end

                4'b0101: begin // MUL
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b10;      // ALU performs MUL
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00;
                end

                4'b0110: begin // DIV
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b11;      // ALU performs DIV
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00;
                end

                4'b0111: begin // LDR (Load Register)
                    rd_addr <= rd;
                    rs_addr <= rs;
                    mem_read_enable <= 1'b1;    // Enable lsu to perform memory read
                    reg_write_enable <= 1'b1;   // Enable Register File write
                    reg_input_mux <= 2'b01;     // Data comes from lsu output
                end

                4'b1000: begin // STR (Store Register)
                    rs_addr <= rs;
                    rt_addr <= rt;
                    mem_write_enable <= 1'b1;   // Enable lsu to perform memory write
                end

                4'b1001: begin // CONST (Load Immediate Constant)
                    rd_addr <= rd;
                    // imm8 is already latched.
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b10;     // Data comes from Immediate value
                end

                4'b1111: begin // RET (Return from Kernel/Block)
                    decoded_ret <= 1'b1; // Assert return signal
                end

                default: begin
                    // For undefined opcodes, all control signals remain de-asserted (acts as NOP).
                end
            endcase
        end
    end

endmodule
