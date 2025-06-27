module scheduler #(
    parameter NUM_THREADS = 4
) (
    input clk, reset,                        // Clock and synchronous reset
    input core_start,                        // From Dispatcher, starts block
    input [7:0] core_block_id,               // From Dispatcher, block ID
    input [7:0] core_thread_count,           // From Dispatcher, threads in block
    input [NUM_THREADS-1:0][1:0] lsu_state,  // From each thread's LSU
    input decoded_ret,                       // From Decoder, signals RET
    output reg [2:0] core_state,             // Pipeline state (000=IDLE, 001=FETCH, etc.)
    output reg core_done,                    // Signals block completion to Dispatcher
    output reg [7:0] block_id,               // To Register Files
    output reg [7:0] threads_per_block,      // To Register Files
    output reg [NUM_THREADS-1:0][7:0] thread_id // To each thread's Register File
);
    // FSM states
    localparam IDLE = 3'b000, FETCH = 3'b001, DECODE = 3'b010,
               REQUEST = 3'b011, EXECUTE = 3'b101, UPDATE = 3'b110;
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Resets state and signals
            core_state <= IDLE;
            core_done <= 1'b0;
            block_id <= 8'b0;
            threads_per_block <= 8'b0;
            for (i = 0; i < NUM_THREADS; i = i + 1)
                thread_id[i] <= 8'b0;
        end else begin
            case (core_state)
                IDLE: begin
                    if (core_start) begin
                        // Initializes Register File parameters
                        block_id <= core_block_id;
                        threads_per_block <= core_thread_count;
                        for (i = 0; i < NUM_THREADS; i = i + 1)
                            thread_id[i] <= i; // Assigns thread IDs 0 to 3
                        // Starts fetching instruction
                        core_state <= FETCH;
                        core_done <= 1'b0;
                    end
                end
                FETCH: begin
                    // Signals Fetcher to retrieve instruction
                    core_state <= DECODE;
                end
                DECODE: begin
                    // Activates Decoder to parse instruction
                    core_state <= REQUEST;
                end
                REQUEST: begin
                    // Enables Register File and LSU operations
                    core_state <= EXECUTE;
                end
                EXECUTE: begin
                    // Triggers ALUs and PC updates
                    core_state <= UPDATE;
                end
                UPDATE: begin
                    // Checks LSU states for memory stall
                    if (decoded_ret) begin
                        // Signals block completion on RET
                        core_done <= 1'b1;
                        core_state <= IDLE;
                    end else if (lsu_state[0] == 2'b11 && lsu_state[1] == 2'b11 &&
                               lsu_state[2] == 2'b11 && lsu_state[3] == 2'b11) begin
                        // Moves to FETCH if all LSUs are DONE
                        core_state <= FETCH;
                    end
                    // Stays in UPDATE if any LSU is not DONE
                end
                default: core_state <= IDLE;
            endcase
        end
    end
endmodule
