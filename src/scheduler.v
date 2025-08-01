// scheduler.v
// Pipeline Scheduler for a single miniGPU core.
// Manages the flow of instructions through the pipeline stages for a block of threads.
// Also signals block completion and handles stalling due to memory operations.

module scheduler #(
    parameter NUM_THREADS = 4
)(
    input clk,
    input reset,
    input core_start,
    input [7:0] core_block_id,
    input [7:0] core_thread_count,
    input [(NUM_THREADS*2)-1:0] lsu_state_flat,
    input decoded_ret,

    output reg [2:0] core_state,
    output reg core_done,

    output reg [7:0] block_id,
    output reg [7:0] threads_per_block,
    output [(NUM_THREADS*8)-1:0] thread_id_flat
);

    localparam IDLE    = 3'b000;
    localparam FETCH   = 3'b001;
    localparam DECODE  = 3'b010;
    localparam REQUEST = 3'b011;
    localparam EXECUTE = 3'b101;
    localparam UPDATE  = 3'b110;

    wire [1:0] lsu_state_internal [0:NUM_THREADS-1];
    reg [7:0] thread_id_internal [0:NUM_THREADS-1];

    genvar i;        
    integer j_loop;  
    reg all_lsus_done_flag; 
    reg loop_exit_flag;     


    genvar i_map; 
    generate
        for (i = 0; i < NUM_THREADS; i = i + 1) begin : port_mapping
            assign lsu_state_internal[i] = lsu_state_flat[i*2 +: 2];
            assign thread_id_flat[i*8 +: 8] = thread_id_internal[i];
        end
    endgenerate


    always @(posedge clk or posedge reset) begin : scheduler_fsm_logic
        if (reset) begin
            core_state <= IDLE;
            core_done <= 1'b0;
            block_id <= 8'b0;
            threads_per_block <= 8'b0;
            for (j_loop = 0; j_loop < NUM_THREADS; j_loop = j_loop + 1) begin
                thread_id_internal[j_loop] <= 8'b0;
            end
            all_lsus_done_flag <= 1'b0; // Reset
            loop_exit_flag <= 1'b0;
        end else begin
            case (core_state)
                IDLE: begin
                    if (core_start) begin
                        block_id <= core_block_id;
                        threads_per_block <= core_thread_count;
                        for (j_loop = 0; j_loop < NUM_THREADS; j_loop = j_loop + 1) begin
                            thread_id_internal[j_loop] <= j_loop;
                        end
                        core_state <= FETCH;
                        core_done <= 1'b0;
                    end
                end

                FETCH: begin
                    core_state <= DECODE;
                end

                DECODE: begin
                    core_state <= REQUEST;
                end

                REQUEST: begin
                    core_state <= EXECUTE;
                end

                EXECUTE: begin
                    core_state <= UPDATE;
                end

                UPDATE: begin
                    if (decoded_ret) begin
                        core_done <= 1'b1;
                        core_state <= IDLE;
                    end
                    else begin
                        // These are now external, so we just assign to them
                        all_lsus_done_flag = 1'b1; // Assign value
                        loop_exit_flag = 1'b0;     // Assign value
                        for (j_loop = 0; j_loop < NUM_THREADS; j_loop = j_loop + 1) begin
                            if (loop_exit_flag == 1'b0) begin
                                if (lsu_state_internal[j_loop] != 2'b11) begin
                                    all_lsus_done_flag = 1'b0;
                                    loop_exit_flag = 1'b1;
                                end
                            end
                        end
                        if (all_lsus_done_flag) begin // Use the module-level flag
                            core_state <= FETCH;
                        end
                    end
                end

                default: core_state <= IDLE;
            endcase
        end
    end

endmodule
