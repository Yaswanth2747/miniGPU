// dispatcher.v
// Workload Dispatcher for the miniGPU system.
// Responsible for receiving kernel launch requests, calculating thread blocks,
// and dispatching these blocks to available processing cores.
// It also tracks core completion and signals overall kernel completion.

module dispatcher #(
    parameter NUM_CORES = 2,           // Parameter: Total number of processing cores in the system.
    parameter THREADS_PER_BLOCK = 4    // Parameter: Number of threads per block, as processed by each core.
)(
    input clk,                         // Clock signal
    input reset,                       // Asynchronous reset signal
    input start,                       // Input from Toplevel: Triggers kernel execution (asserted once by host).
    input [7:0] thread_count,          // Input from DCR: Total number of threads to be executed by the kernel.
    input [NUM_CORES-1:0] core_done,   // Input from Cores: Array of signals, each bit indicates a core has finished its block.

    output reg [NUM_CORES-1:0] core_start,     // Output to Cores: Array of signals, each bit to start a specific core.
    output reg [NUM_CORES-1:0] core_reset,     // Output to Cores: Array of signals, each bit to reset a specific core.
    output reg [(8*NUM_CORES)-1:0] core_block_id_flat,     // Output to Cores: Flattened block ID assigned to each core.
    output reg [(8*NUM_CORES)-1:0] core_thread_count_flat, // Output to Cores: Flattened thread count for each core's block.
    output reg done                            // Output to Toplevel: Signals that the entire kernel execution is complete.
);

    // ====================================================================
    // Internal Registers for Dispatcher State and Counters
    // ====================================================================

    // Counts how many blocks have been assigned to cores so far.
    reg [7:0] blocks_dispatched;
    // Counts how many blocks have completed their execution (signaled by core_done).
    reg [7:0] blocks_done;
    // Stores the total number of blocks required for the entire kernel.
    reg [7:0] total_blocks;

    // FSM states for the Dispatcher's operation.
    localparam IDLE         = 2'b00; // Dispatcher is idle, waiting for a 'start' signal.
    localparam DISPATCHING  = 2'b01; // Dispatcher is actively assigning blocks to cores.
    localparam WAITING      = 2'b10; // (Unused in current logic, but common for pipeline arbitration)
                                     //   Could be used for more complex handshake.
    reg [1:0] state; // Current state of the Dispatcher FSM.

    // ====================================================================
    // Loop variables declared at the module level for Verilog-2001 compatibility.
    // ====================================================================
    integer j_loop; // For procedural loops (inside always/initial blocks)
    genvar i_gen;   // For generate blocks (if any, not directly in this module, but good practice)


    // ====================================================================
    // Main Sequential Logic: Dispatcher FSM and Control
    // ====================================================================
    always @(posedge clk or posedge reset) begin : dispatcher_fsm_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // On reset, clear all counters, states, and control outputs.
            state <= IDLE;
            blocks_dispatched <= 8'b0;
            blocks_done <= 8'b0;
            total_blocks <= 8'b0;
            done <= 1'b0; // Overall kernel not done
            for (j_loop = 0; j_loop < NUM_CORES; j_loop = j_loop + 1) begin
                core_start[j_loop] <= 1'b0;  // No cores are started
                core_reset[j_loop] <= 1'b1;  // Hold all cores in reset initially
                core_block_id_flat[j_loop*8 +: 8] <= 8'b0;     // Clear block IDs
                core_thread_count_flat[j_loop*8 +: 8] <= 8'b0; // Clear thread counts
            end
        end else begin
            case (state)
                IDLE: begin
                    // In IDLE, wait for the global 'start' signal from the Toplevel/Host.
                    if (start) begin
                        state <= DISPATCHING; // Move to DISPATCHING state
                        // Calculate total blocks required: ceil(thread_count / THREADS_PER_BLOCK)
                        // (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK performs ceiling division.
                        total_blocks <= (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

                        // Release all cores from reset so they can accept new blocks.
                        // This must be done here, as cores need to run to signal 'core_done'.
                        for (j_loop = 0; j_loop < NUM_CORES; j_loop = j_loop + 1) begin
                            core_reset[j_loop] <= 1'b0; // Release core from reset
                        end
                        done <= 1'b0; // Reset overall done signal
                    end
                end

                DISPATCHING: begin
                    // In DISPATCHING, continuously try to assign blocks to available cores
                    // and monitor core completion.

                    // 1. Assign blocks to idle cores:
                    for (j_loop = 0; j_loop < NUM_CORES; j_loop = j_loop + 1) begin
                        // Check if more blocks need to be dispatched, AND
                        // if this core is not currently busy (core_start is low), AND
                        // if this core is not held in reset.
                        if ((blocks_dispatched < total_blocks) && (!core_start[j_loop]) && (!core_reset[j_loop])) begin
                            core_start[j_loop] <= 1'b1; // Assert core_start to assign a new block
                            core_block_id_flat[j_loop*8 +: 8] <= blocks_dispatched; // Assign next available block ID

                            // Calculate thread count for this specific block:
                            // For the last block, it might be fewer than THREADS_PER_BLOCK.
                            if (blocks_dispatched == total_blocks - 1) begin
                                // This is the last block. Calculate remaining threads.
                                core_thread_count_flat[j_loop*8 +: 8] <= (thread_count - (blocks_dispatched * THREADS_PER_BLOCK));
                            end else begin
                                // Not the last block, assign a full block of threads.
                                core_thread_count_flat[j_loop*8 +: 8] <= THREADS_PER_BLOCK;
                            end
                            blocks_dispatched <= blocks_dispatched + 1; // Increment dispatched counter
                        end
                    end

                    // 2. Check for core completion:
                    for (j_loop = 0; j_loop < NUM_CORES; j_loop = j_loop + 1) begin
                        // If a core signals 'core_done' AND it was previously 'core_start'ed (meaning it finished a block)
                        if (core_done[j_loop] && core_start[j_loop]) begin
                            core_start[j_loop] <= 1'b0; // De-assert core_start (block is finished for this core)
                            core_reset[j_loop] <= 1'b1; // Put core in reset momentarily
                            blocks_done <= blocks_done + 1; // Increment done counter
                            // Immediately de-assert reset after one cycle to make it ready for next block
                            // (If Dispatcher needs to assign it a new block, it will see !core_reset[j_loop])
                            // This depends on the core's reset logic. If core has asynchronous reset, it will reset instantly.
                            // If it's synchronous reset, it will reset on next clock edge.
                            core_reset[j_loop] <= 1'b0;
                        end
                    end

                    // 3. Check for overall kernel completion:
                    // If all blocks have been dispatched AND all blocks have completed,
                    // then the entire kernel execution is done.
                    if ((blocks_done == total_blocks) && (total_blocks != 8'b0)) begin // total_blocks != 0 check avoids immediate done if thread_count=0
                        done <= 1'b1; // Assert overall kernel done signal
                        state <= IDLE; // Return to IDLE, waiting for a new kernel launch
                    end
                end

                // WAITING: (Optional state, not currently used but included as localparam)
                // This state could be used for more complex handshake or delay logic if needed.
                WAITING: begin
                    // Currently, no specific logic here. Just a placeholder.
                end

                default: state <= IDLE; // Safety net: Default to IDLE state
            endcase
        end
    end

endmodule
