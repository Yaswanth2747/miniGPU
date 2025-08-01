// mem_controller.v
// Memory Controller for the miniGPU system.
// This module acts as an arbiter and interface manager for all
// memory requests coming from the Load/Store Units (LSUs) of all cores.
// It consolidates these requests, arbitrates access based on priority,
// and communicates with the single external memory module (memory.v).

module mem_controller #(
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8,
    parameter NUM_CONSUMERS = 8,
    parameter NUM_CHANNELS = 2
)(
    input clk,
    input reset,

    input [NUM_CONSUMERS-1:0] consumer_read_valid,
    input [NUM_CONSUMERS-1:0] consumer_write_valid,
    input [(NUM_CONSUMERS*ADDR_BITS)-1:0] consumer_read_address,
    input [(NUM_CONSUMERS*ADDR_BITS)-1:0] consumer_write_address,
    input [(NUM_CONSUMERS*DATA_BITS)-1:0] consumer_write_data,

    output reg [NUM_CONSUMERS-1:0] consumer_ready,
    output reg [(NUM_CONSUMERS*DATA_BITS)-1:0] consumer_read_data,

    input mem_read_ready,
    input mem_write_ready,
    input [DATA_BITS-1:0] mem_read_data,

    output reg mem_read_valid,
    output reg mem_write_valid,
    output reg [ADDR_BITS-1:0] mem_read_address,
    output reg [DATA_BITS-1:0] mem_write_address,
    output reg [DATA_BITS-1:0] mem_write_data
);

    localparam IDLE         = 2'b00;
    localparam PROCESSING   = 2'b01;
    localparam WAITING      = 2'b10;
    localparam COMPLETION   = 2'b11;

    reg [1:0] state [0:NUM_CHANNELS-1];
    reg [NUM_CONSUMERS-1:0] served_bitmap;
    reg [$clog2(NUM_CONSUMERS)-1:0] current_consumer [0:NUM_CHANNELS-1];

    wire [ADDR_BITS-1:0] consumer_read_address_internal [0:NUM_CONSUMERS-1];
    wire [ADDR_BITS-1:0] consumer_write_address_internal [0:NUM_CONSUMERS-1];
    wire [DATA_BITS-1:0] consumer_write_data_internal [0:NUM_CONSUMERS-1];

    // --- CRUCIAL FIX HERE ---
    // Loop variables declared AT THE MODULE LEVEL for Verilog-2001 compatibility.
    genvar i_gen;         // For generate blocks
    integer j_loop;       // For procedural loops (inside always/initial blocks)
    integer j_idx;        // MOVED HERE from inside IDLE state
    reg found_request_flag; // MOVED HERE from inside IDLE state (renamed for clarity)


    // Unpacking Input Ports (Flattened to Unpacked Internal Wires)
    generate
        for (i_gen = 0; i_gen < NUM_CONSUMERS; i_gen = i_gen + 1) begin : input_unpacking
            assign consumer_read_address_internal[i_gen]  = consumer_read_address[i_gen*ADDR_BITS +: ADDR_BITS];
            assign consumer_write_address_internal[i_gen] = consumer_write_address[i_gen*ADDR_BITS +: ADDR_BITS];
            assign consumer_write_data_internal[i_gen]    = consumer_write_data[i_gen*DATA_BITS +: DATA_BITS];
        end
    endgenerate


    always @(posedge clk or posedge reset) begin : mem_controller_fsm_logic
        if (reset) begin
            for (j_loop = 0; j_loop < NUM_CHANNELS; j_loop = j_loop + 1) begin
                state[j_loop] <= IDLE;
                current_consumer[j_loop] <= {($clog2(NUM_CONSUMERS)){1'b0}};
            end
            served_bitmap <= {NUM_CONSUMERS{1'b0}};
            consumer_ready <= {NUM_CONSUMERS{1'b0}};

            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;
            mem_read_address <= {ADDR_BITS{1'b0}};
            mem_write_address <= {ADDR_BITS{1'b0}};
            mem_write_data <= {DATA_BITS{1'b0}};

            for (j_loop = 0; j_loop < NUM_CONSUMERS; j_loop = j_loop + 1) begin
                consumer_read_data[j_loop*DATA_BITS +: DATA_BITS] <= {DATA_BITS{1'b0}};
            end
            // Reset module-level flags here too
            found_request_flag <= 1'b0;
        end else begin
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;

            for (j_loop = 0; j_loop < NUM_CHANNELS; j_loop = j_loop + 1) begin
                case (state[j_loop])
                    IDLE: begin
                        // Initialize flag for this cycle's arbitration
                        found_request_flag = 1'b0; // This is a combinatorial assignment (blocking)

                        for (j_idx = 0; j_idx < NUM_CONSUMERS; j_idx = j_idx + 1) begin // Use module-level j_idx
                            if (found_request_flag == 1'b0) begin // Check flag before each iteration (like 'break')
                                if (!served_bitmap[j_idx] && (consumer_read_valid[j_idx] || consumer_write_valid[j_idx])) begin
                                    state[j_loop] <= PROCESSING;
                                    current_consumer[j_loop] <= j_idx;
                                    served_bitmap[j_idx] <= 1'b1;

                                    if (consumer_read_valid[j_idx]) begin
                                        mem_read_valid <= 1'b1;
                                        mem_read_address <= consumer_read_address_internal[j_idx];
                                    end
                                    else if (consumer_write_valid[j_idx]) begin
                                        mem_write_valid <= 1'b1;
                                        mem_write_address <= consumer_write_address_internal[j_idx];
                                        mem_write_data <= consumer_write_data_internal[j_idx];
                                    end
                                    found_request_flag = 1'b1; // Set flag to exit the inner loop
                                end
                            end
                        end // end for (j_idx)
                    end
                    PROCESSING: begin
                        if (mem_read_valid && mem_read_ready) begin
                            consumer_read_data[current_consumer[j_loop]*DATA_BITS +: DATA_BITS] <= mem_read_data;
                            mem_read_valid <= 1'b0;
                            state[j_loop] <= WAITING;
                        end else if (mem_write_valid && mem_write_ready) begin
                            mem_write_valid <= 1'b0;
                            state[j_loop] <= WAITING;
                        end
                    end
                    WAITING: begin
                        if (!consumer_read_valid[current_consumer[j_loop]] && !consumer_write_valid[current_consumer[j_loop]]) begin
                            state[j_loop] <= COMPLETION;
                            consumer_ready[current_consumer[j_loop]] <= 1'b1;
                        end
                    end
                    COMPLETION: begin
                        consumer_ready[current_consumer[j_loop]] <= 1'b0;
                        served_bitmap[current_consumer[j_loop]] <= 1'b0;
                        state[j_loop] <= IDLE;
                    end
                    default: state[j_loop] <= IDLE;
                endcase
            end // end for (j_loop) loop through channels
        end
    end // end always @(posedge clk or posedge reset)

endmodule
