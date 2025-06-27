module MemoryController #(
    parameter ADDR_BITS = 8, // for future scalability
    parameter DATA_BITS = 8, // data is single byte
    parameter NUM_CONSUMERS = 8,  // Total #LSUs
    parameter NUM_CHANNELS = 2    // takin 2 concurrent mem channels for now
) (
    input clk, reset,
    input [NUM_CONSUMERS-1:0] consumer_read_valid, consumer_write_valid,
    input [NUM_CONSUMERS-1:0][ADDR_BITS-1:0] consumer_read_address, consumer_write_address,
    input [NUM_CONSUMERS-1:0][DATA_BITS-1:0] consumer_write_data,
    input mem_read_ready, mem_write_ready,
    input [DATA_BITS-1:0] mem_read_data,
    output reg [NUM_CONSUMERS-1:0] consumer_ready,
    output reg [DATA_BITS-1:0] consumer_read_data [0:NUM_CONSUMERS-1],
    output reg mem_read_valid, mem_write_valid,
    output reg [ADDR_BITS-1:0] mem_read_address, mem_write_address,
    output reg [DATA_BITS-1:0] mem_write_data
);
    // FSM states
    localparam IDLE = 2'b00, PROCESSING = 2'b01, WAITING = 2'b10, COMPLETION = 2'b11;
    
    // Per-channel FSM state and consumer being served
    reg [1:0] state [0:NUM_CHANNELS-1];            // each state will have 2 elements
    reg [NUM_CONSUMERS-1:0] served_bitmap;         // Tracks served consumers, as given in the doc miniGPU.pdf, this prevents multiple channels from serving the same LSU.
    reg [2:0] current_consumer [0:NUM_CHANNELS-1]; // Consumer ID per channel
    
    integer i, j;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                state[i] <= IDLE;
                current_consumer[i] <= 3'b0;
            end
            served_bitmap <= {NUM_CONSUMERS{1'b0}};
            consumer_ready <= {NUM_CONSUMERS{1'b0}};
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;
            mem_read_address <= {ADDR_BITS{1'b0}};
            mem_write_address <= {ADDR_BITS{1'b0}};
            mem_write_data <= {DATA_BITS{1'b0}};
            for (i = 0; i < NUM_CONSUMERS; i = i + 1)
                consumer_read_data[i] <= {DATA_BITS{1'b0}};
        end else begin
            // Processing each channel
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                case (state[i])
                    IDLE: begin
                        // Scanning for unserved consumer (priority from 0)
                        for (j = 0; j < NUM_CONSUMERS; j = j + 1) begin
                            if (!served_bitmap[j] && (consumer_read_valid[j] || consumer_write_valid[j])) begin
                                state[i] <= PROCESSING;
                                current_consumer[i] <= j;
                                served_bitmap[j] <= 1'b1;
                                if (consumer_read_valid[j]) begin
                                    mem_read_valid <= 1'b1;
                                    mem_read_address <= consumer_read_address[j];
                                end else if (consumer_write_valid[j]) begin
                                    mem_write_valid <= 1'b1;
                                    mem_write_address <= consumer_write_address[j];
                                    mem_write_data <= consumer_write_data[j];
                                end
                                break;
                            end
                        end
                    end
                    PROCESSING: begin
                        // issue mem cmd
                        if (mem_read_valid && mem_read_ready) begin
                            state[i] <= WAITING;
                            mem_read_valid <= 1'b0;
                            consumer_read_data[current_consumer[i]] <= mem_read_data;
                        end else if (mem_write_valid && mem_write_ready) begin
                            state[i] <= WAITING;
                            mem_write_valid <= 1'b0;
                        end
                    end
                    WAITING: begin
                        // waiting for consumer
                        if (!consumer_read_valid[current_consumer[i]] && !consumer_write_valid[current_consumer[i]]) begin
                            state[i] <= COMPLETION;
                            consumer_ready[current_consumer[i]] <= 1'b1;
                        end
                    end
                    COMPLETION: begin
                        // clearing consumer_ready and returning to IDLE
                        consumer_ready[current_consumer[i]] <= 1'b0;
                        served_bitmap[current_consumer[i]] <= 1'b0;
                        state[i] <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule
