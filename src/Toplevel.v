module Toplevel #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
)(
    input clk, reset, start
);
    wire [7:0] thread_count;
    wire [NUM_CORES-1:0] core_start, core_reset, core_done;
    wire [7:0] core_block_id [0:NUM_CORES-1];
    wire [7:0] core_thread_count [0:NUM_CORES-1];

    wire [7:0] consumer_read_addr [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire [7:0] consumer_write_addr [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire [7:0] consumer_write_data [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire [7:0] consumer_read_data [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire consumer_read_valid [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire consumer_write_valid [0:NUM_CORES*THREADS_PER_BLOCK-1];
    wire consumer_ready [0:NUM_CORES*THREADS_PER_BLOCK-1];

    // Device Control Register
    DeviceControlRegister DCR (
        .clk(clk), .reset(reset),
        .device_control_write_enable(start),
        .device_control_data(8'd8), // 8 threads total for 2 cores × 4 threads
        .thread_count(thread_count)
    );

    // Dispatcher
    Dispatcher #(.NUM_CORES(NUM_CORES), .THREADS_PER_BLOCK(THREADS_PER_BLOCK)) DISPATCH (
        .clk(clk), .reset(reset),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .done()
    );

    // Core Instances
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : cores
            core #(.NUM_THREADS(THREADS_PER_BLOCK)) CORE_INST (
                .clk(clk), .reset(core_reset[i]),
                .core_start(core_start[i]),
                .core_block_id(core_block_id[i]),
                .core_thread_count(core_thread_count[i]),
                .core_done(core_done[i]),
                .lsu_read_valid(consumer_read_valid[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_write_valid(consumer_write_valid[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_read_addr(consumer_read_addr[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_write_addr(consumer_write_addr[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_write_data(consumer_write_data[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_ready(consumer_ready[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_read_data(consumer_read_data[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK])
            );
        end
    endgenerate

    // Memory Controller
    MemoryController #(
        .ADDR_BITS(8),
        .DATA_BITS(8),
        .NUM_CONSUMERS(NUM_CORES * THREADS_PER_BLOCK),
        .NUM_CHANNELS(2)
    ) MEMCTRL (
        .clk(clk), .reset(reset),
        .consumer_read_valid(consumer_read_valid),
        .consumer_write_valid(consumer_write_valid),
        .consumer_read_address(consumer_read_addr),
        .consumer_write_address(consumer_write_addr),
        .consumer_write_data(consumer_write_data),
        .consumer_ready(consumer_ready),
        .consumer_read_data(consumer_read_data),
        .mem_read_ready(1'b1), // Assume always ready
        .mem_write_ready(1'b1),
        .mem_read_data(8'hAA), // Dummy data
        .mem_read_valid(),
        .mem_write_valid(),
        .mem_read_address(),
        .mem_write_address(),
        .mem_write_data()
    );

endmodule
