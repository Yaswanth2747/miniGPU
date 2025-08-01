// fetcher.v
// Instruction Fetch Unit for a single miniGPU core.
// Retrieves instructions from a hardcoded program memory (ROM) based on the PC.

module fetcher #( // Module name is lowercase: fetcher
    parameter NUM_THREADS = 4,
    parameter ADDR_BITS = 8,
    parameter INSTR_BITS = 16
)(
    input clk,
    input reset,
    input [2:0] core_state,
    input [(NUM_THREADS*ADDR_BITS)-1:0] current_pc_flat,

    output reg [INSTR_BITS-1:0] instruction,
    output [(NUM_THREADS*ADDR_BITS)-1:0] pc_out_flat
);

    reg [INSTR_BITS-1:0] program_memory [0:2**ADDR_BITS-1];

    // Internal unpacked array for current_pc.
    wire [ADDR_BITS-1:0] current_pc_internal [0:NUM_THREADS-1];
    // Internal unpacked array for output PCs.
    reg [ADDR_BITS-1:0] pc_out_internal [0:NUM_THREADS-1];

    genvar i_map;
    integer j_loop;


    // Combinational logic (continuous assignment) to map the flattened input port
    // to the internal unpacked array.
    generate
        for (i_map = 0; i_map < NUM_THREADS; i_map = i_map + 1) begin : input_pc_mapping
            assign current_pc_internal[i_map] = current_pc_flat[i_map*ADDR_BITS +: ADDR_BITS];
        end
    endgenerate

    // Combinational logic (continuous assignment) to map the internal unpacked array
    // to the flattened output port.
    generate
        for (i_map = 0; i_map < NUM_THREADS; i_map = i_map + 1) begin : output_pc_mapping
            assign pc_out_flat[i_map*ADDR_BITS +: ADDR_BITS] = pc_out_internal[i_map];
        end
    endgenerate


    // Initializes program memory with example instructions.
    // This 'initial' block will be translated into a ROM in synthesis.
    initial begin : program_mem_init
        // $display("[%0t] FETCHER: Initializing program memory...", $time); // REMOVED FOR SYNTHESIS
        
        program_memory[0]  = 16'b1001_0001_00001010;
        program_memory[1]  = 16'b0011_0001_0001_1110;
        program_memory[2]  = 16'b0111_0010_0001_0000;
        program_memory[3]  = 16'b1001_0011_00001011;
        program_memory[4]  = 16'b0011_0011_0011_1110;
        program_memory[5]  = 16'b0111_0100_0011_0000;
        program_memory[6]  = 16'b0011_0101_0010_0100;
        program_memory[7]  = 16'b1001_0110_00001100;
        program_memory[8]  = 16'b0011_0110_0110_1110;
        program_memory[9]  = 16'b1000_0000_0110_0101;
        program_memory[10] = 16'b1111_0000_0000_0000;

        for (j_loop = 11; j_loop < (2**ADDR_BITS); j_loop = j_loop + 1) begin
            program_memory[j_loop] = 16'b0000_0000_0000_0000; // NOP (Opcode 0000)
        end
        // $display("[%0t] FETCHER: Program memory initialized.", $time); // REMOVED FOR SYNTHESIS
    end

    // Main sequential logic for fetching instructions.
    always @(posedge clk or posedge reset) begin : fetch_proc_logic
        if (reset) begin
            instruction <= {INSTR_BITS{1'b0}};
            for (j_loop = 0; j_loop < NUM_THREADS; j_loop = j_loop + 1) begin
                pc_out_internal[j_loop] <= {ADDR_BITS{1'b0}};
            end
        end else if (core_state == 3'b001) begin
            instruction <= program_memory[current_pc_internal[0]];
            // $display("[%0t] FETCHER: Fetched instruction 0x%H from PC 0x%H", $time, program_memory[current_pc_internal[0]], current_pc_internal[0]); // REMOVED FOR SYNTHESIS

            for (j_loop = 0; j_loop < NUM_THREADS; j_loop = j_loop + 1) begin
                pc_out_internal[j_loop] <= current_pc_internal[j_loop];
            end
        end
    end

endmodule
