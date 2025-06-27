module Dispatcher #( //here # is to include parameters, we can change them when we instantiate them. 
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input clk, reset,                    // Clock and synchronous reset
    input start,                        // Triggers kernel execution
    input [7:0] thread_count,           // Total threads from DCR
    input [NUM_CORES-1:0] core_done,    // Signals block completion per core
    output reg [NUM_CORES-1:0] core_start, core_reset, // Start and reset signals per core
    output reg [NUM_CORES-1:0][7:0] core_block_id,    // Block ID per core
    output reg [NUM_CORES-1:0][7:0] core_thread_count,// Thread count per block
    output reg done                     // Signals kernel completion
);
    // Tracks dispatched and completed blocks
    reg [7:0] blocks_dispatched, blocks_done;
    // Calculates total blocks
    reg [7:0] total_blocks;
    
    // FSM states
    localparam IDLE = 2'b00, DISPATCHING = 2'b01, WAITING = 2'b10;
    reg [1:0] state;
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Resets counters and signals
            state <= IDLE;
            blocks_dispatched <= 8'b0;
            blocks_done <= 8'b0;
            total_blocks <= 8'b0;
            done <= 1'b0;
            for (i = 0; i < NUM_CORES; i = i + 1) begin
                core_start[i] <= 1'b0;
                core_reset[i] <= 1'b1; // Holds cores in reset
                core_block_id[i] <= 8'b0;
                core_thread_count[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Starts dispatching on start signal
                        state <= DISPATCHING;
                        // Calculates total blocks: ceil(thread_count / THREADS_PER_BLOCK)
                        total_blocks <= (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
                        for (i = 0; i < NUM_CORES; i = i + 1)
                            core_reset[i] <= 1'b0; // Releases cores
                    end
                end
                DISPATCHING: begin
                    // Assigns blocks to idle cores
                    for (i = 0; i < NUM_CORES; i = i + 1) begin
                        if (blocks_dispatched < total_blocks && !core_start[i] && !core_reset[i]) begin
                            core_start[i] <= 1'b1;
                            core_block_id[i] <= blocks_dispatched;
                            // Sets thread count (adjusts for last block)
                            core_thread_count[i] <= (blocks_dispatched == total_blocks - 1) ?
                                (thread_count - (blocks_dispatched * THREADS_PER_BLOCK)) :
                                THREADS_PER_BLOCK;
                            blocks_dispatched <= blocks_dispatched + 1;
                        end
                    end
                    // Checks for core completion
                    for (i = 0; i < NUM_CORES; i = i + 1) begin
                        if (core_done[i] && core_start[i]) begin
                            core_start[i] <= 1'b0;
                            core_reset[i] <= 1'b1;
                            blocks_done <= blocks_done + 1;
                            // Releases reset after one cycle
                            core_reset[i] <= 1'b0;
                        end
                    end
                    // Signals completion when all blocks are done
                    if (blocks_done == total_blocks && total_blocks != 0) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
