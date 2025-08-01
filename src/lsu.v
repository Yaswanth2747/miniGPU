// lsu.v
// Load/Store Unit (LSU) for a single miniGPU thread.
// Handles memory read (LDR) and memory write (STR) operations.
// Communicates with the MemoryController to perform actual memory access.

module lsu (
    input clk,
    input reset,                             
    input enable,                            // Enable signal for this LSU instance (from core)
    input [2:0] core_state,                  // Current pipeline state from Scheduler (e.g., 3'b011=REQUEST, 3'b110=UPDATE)

    // Signals from Decoder (indicating a memory operation)
    input decoded_mem_read_enable,           // 1 if the current instruction is LDR
    input decoded_mem_write_enable,          // 1 if the current instruction is STR

    // Inputs from Register File (operands for memory access)
    // For LDR: rs is address.
    // For STR: rs is address, rt is data to store.
    input [7:0] rs,                          // Register Source 1 data (typically memory address)
    input [7:0] rt,                          // Register Source 2 data (typically data to be written for STR)

    // Signals from MemoryController (memory response)
    input mem_read_ready,                    // MemoryController ready to accept a read request
    input mem_write_ready,                   // MemoryController ready to accept a write request
    input [7:0] mem_read_data,               // Data received from MemoryController on a read operation

    // Outputs to Register File
    output reg [7:0] lsu_out,                // Data read from memory (for LDR, goes to Register File)

    // Outputs to Scheduler
    output reg [1:0] lsu_state,              // Current state of this LSU (reported to Scheduler for stalling)
                                             //   2'b00: IDLE
                                             //   2'b01: REQUESTING (Memory request sent)
                                             //   2'b10: WAITING (Memory acknowledged, waiting for Scheduler to proceed)
                                             //   2'b11: DONE (Memory operation fully complete and acknowledged)

    // Outputs to MemoryController (memory request)
    output reg mem_read_valid,               // Asserted to request a memory read
    output reg mem_write_valid,              // Asserted to request a memory write
    output reg [7:0] mem_read_address,       // Address for memory read request
    output reg [7:0] mem_write_address,      // Address for memory write request
    output reg [7:0] mem_write_data          // Data for memory write request
);

    // FSM states for the LSU's operation
    localparam IDLE       = 2'b00; // LSU is idle, no memory operation in progress
    localparam REQUESTING = 2'b01; // LSU has sent a memory request to the MemoryController
    localparam WAITING    = 2'b10; // MemoryController has acknowledged, waiting for core's UPDATE stage
    localparam DONE       = 2'b11; // Memory operation is fully complete for this instruction

    // Main sequential logic for the LSU's state machine and operations
    always @(posedge clk or posedge reset) begin : lsu_fsm_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // On reset, initialize all state and output signals
            lsu_state <= IDLE;
            lsu_out <= 8'b0;
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;
            mem_read_address <= 8'b0;
            mem_write_address <= 8'b0;
            mem_write_data <= 8'b0;
        end else if (enable) begin // Only operate if the LSU is enabled by the core
            // Default assignments for outputs that are pulsed or cleared
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;

            case (lsu_state)
                IDLE: begin
                    // In IDLE, wait for a new memory request from the Decoder,
                    // which happens when the core is in the 'REQUEST' stage.
                    if (core_state == 3'b011) begin // REQUEST state from Scheduler
                        if (decoded_mem_read_enable) begin
                            // If it's an LDR (Load Register) instruction
                            lsu_state <= REQUESTING;        // Move to REQUESTING state
                            mem_read_valid <= 1'b1;         // Assert read request valid
                            mem_read_address <= rs;         // Use rs as the memory address
                        end else if (decoded_mem_write_enable) begin
                            // If it's an STR (Store Register) instruction
                            lsu_state <= REQUESTING;        // Move to REQUESTING state
                            mem_write_valid <= 1'b1;        // Assert write request valid
                            mem_write_address <= rs;        // Use rs as the memory address
                            mem_write_data <= rt;           // Use rt as the data to write
                        end
                    end
                end

                REQUESTING: begin
                    // In REQUESTING, we've sent the request to MemoryController.
                    // Now, wait for the MemoryController to signal readiness.
                    if (mem_read_valid && mem_read_ready) begin
                        // Read request acknowledged by MemoryController
                        lsu_out <= mem_read_data; // Latch the data received from memory
                        mem_read_valid <= 1'b0;   // De-assert read request valid
                        lsu_state <= WAITING;     // Move to WAITING state
                    end else if (mem_write_valid && mem_write_ready) begin
                        // Write request acknowledged by MemoryController
                        mem_write_valid <= 1'b0;  // De-assert write request valid
                        lsu_state <= WAITING;     // Move to WAITING state
                    end
                    // If not ready, stay in REQUESTING state and keep valid signals asserted (handled by default above)
                end

                WAITING: begin
                    // In WAITING, the memory operation itself is done, but the LSU
                    // needs to wait for the core's pipeline to reach the 'UPDATE' stage
                    // to ensure data is written back (for LDR) or flags are updated.
                    if (core_state == 3'b110) begin // UPDATE state from Scheduler
                        lsu_state <= DONE; // Memory op is completely done for this instruction
                    end
                end

                DONE: begin
                    // In DONE, the LSU has completed its part for the current instruction.
                    // It stays in DONE until the core's pipeline moves out of the UPDATE stage
                    // (signaling that a new instruction is being fetched/decoded).
                    if (core_state != 3'b110) begin // Core pipeline has moved past UPDATE
                        lsu_state <= IDLE; // Return to IDLE, ready for the next instruction
                    end
                end

                default: lsu_state <= IDLE; // Safety default
            endcase
        end
    end

endmodule
