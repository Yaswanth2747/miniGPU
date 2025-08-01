// Toplevel.v
//
// This is the top-level module for the miniGPU system.
// It serves as the main integration point, defining the overall architecture
// by connecting various sub-modules that together form the miniGPU.
//
// Key Responsibilities:
// - Defines global parameters for the GPU's configuration (e.g., number of cores, data widths).
// - Declares all necessary wires for inter-module communication.
// - Instantiates all major sub-modules (like Dispatcher, Cores, MemoryController, Memory).
// - Connects the ports of these sub-modules to the global inputs/outputs and internal wires.

module Toplevel #(
    parameter NUM_CORES = 2,           // Specifies the number of independent processing cores in the GPU.
                                       
    parameter THREADS_PER_BLOCK = 4,   // Defines the number of threads that each core can execute
                                       // concurrently (in a SIMT fashion). This is equivalent to a 'warp'
                                       // or 'wavefront' size in real GPUs.
                                       
    parameter ADDR_BITS = 8,           // Defines the width of memory addresses in bits.
    parameter DATA_BITS = 8,           // Defines the width of data paths in bits (e.g., register width, memory data width).
    parameter INSTR_BITS = 16          // Defines the fixed width of each instruction in bits.
                                       // Our simplified ISA uses 16-bit instructions.
)(
    input clk,     
    input reset,   
    input start,   // Host 'start' signal: This signal initiates the execution of a kernel
                   //                      on the miniGPU. For simplicity, it also acts
                   //                      as the write enable for the Device Control Register (DCR).

    output done_kernel_complete // Output to testbench: Signals that the entire kernel execution is complete.
);

    // --------------------------------------------------------------------
    // 1. Wires for Device Control Register (dcr) & dispatcher interaction
    // --------------------------------------------------------------------
    // thread_count: Output from dcr, input to dispatcher.
    // Specifies the total number of threads that the kernel will launch.
    wire [7:0] thread_count;


    // --------------------------------------------------------------------
    // 2. Wires for dispatcher and core instances interaction
    // (These signals are arrays, where each element corresponds to a specific core)
    // --------------------------------------------------------------------
    // core_start: dispatcher asserts this to tell a specific core to begin processing its assigned block.
    //             Each bit corresponds to a specific core (e.g., core_start[0] for core 0, core_start[1] for core 1).
    wire [NUM_CORES-1:0] core_start;
    // core_reset: dispatcher can assert this to reset individual cores (e.g., after a block completes).
    //             Each bit corresponds to a specific core.
    wire [NUM_CORES-1:0] core_reset;
    // core_done: Asserted by a core when it has finished processing its assigned block of threads.
    //            This signal is sent back to the dispatcher. Each bit corresponds to a specific core.
    wire [NUM_CORES-1:0] core_done;

    // core_block_id_flat: Flattened wire for transmitting block IDs to each core.
    // Each core receives an 8-bit block ID (0 to 255).
    // Total width = 8 bits/block * NUM_CORES.
    wire [(8*NUM_CORES)-1:0] core_block_id_flat;

    // core_thread_count_flat: Flattened wire for transmitting the number of threads in the current block
    // to each core. This handles cases where the last block might have fewer than THREADS_PER_BLOCK threads.
    // Each core receives an 8-bit thread count.
    // Total width = 8 bits/count * NUM_CORES.
    wire [(8*NUM_CORES)-1:0] core_thread_count_flat;


    // --------------------------------------------------------------------
    // 3. Wires for Load/Store Units (LSUs) within Cores and mem_controller interaction
    // (These signals represent aggregated requests from ALL LSUs across ALL cores)
    // --------------------------------------------------------------------
    // localparam for convenience: Total number of individual LSUs in the system.
    // This simplifies array sizing.
    // E.g., for NUM_CORES=2, THREADS_PER_BLOCK=4 => NUM_CONSUMERS = 8.
    localparam NUM_CONSUMERS = NUM_CORES * THREADS_PER_BLOCK;

    // Single-bit valid/ready signals for each consumer (LSU)
    wire [NUM_CONSUMERS-1:0] consumer_read_valid;   // Asserted by an LSU when it wants to read from memory
    wire [NUM_CONSUMERS-1:0] consumer_write_valid;  // Asserted by an LSU when it wants to write to memory
    wire [NUM_CONSUMERS-1:0] consumer_ready;         // Signal from mem_controller, indicates LSU's request is handled

    // Flattened wires for consumer (LSU) addresses and data
    // Each address is ADDR_BITS wide, each data is DATA_BITS wide.
    // Total width for addresses = (ADDR_BITS * NUM_CONSUMERS).
    // Total width for data = (DATA_BITS * NUM_CONSUMERS).
    wire [(ADDR_BITS*NUM_CONSUMERS)-1:0] consumer_read_addr_flat;   // Memory address for a read request
    wire [(DATA_BITS*NUM_CONSUMERS)-1:0] consumer_read_data_flat;   // Data read from memory, sent back to an LSU
    wire [(ADDR_BITS*NUM_CONSUMERS)-1:0] consumer_write_addr_flat;  // Memory address for a write request
    wire [(DATA_BITS*NUM_CONSUMERS)-1:0] consumer_write_data_flat;  // Data to be written by an LSU


    // --------------------------------------------------------------------
    // 4. Wires for mem_controller and External memory module interaction
    // (These signals represent the single, consolidated interface to the main memory)
    // --------------------------------------------------------------------
    // mem_read_valid_o: Output from mem_controller to External memory, requests a read.
    wire mem_read_valid_o;
    // mem_write_valid_o: Output from mem_controller to External memory, requests a write.
    wire mem_write_valid_o;
    // mem_read_address_o: Output from mem_controller to External memory, specifies read address.
    wire [ADDR_BITS-1:0] mem_read_address_o;
    // mem_write_address_o: Output from mem_controller to External memory, specifies write address.
    wire [DATA_BITS-1:0] mem_write_address_o;
    // mem_write_data_o: Output from mem_controller to External memory, specifies data to write.
    wire [DATA_BITS-1:0] mem_write_data_o;

    // mem_read_ready_i: Input to mem_controller from External memory, indicates it's ready for a read.
    wire mem_read_ready_i;
    // mem_write_ready_i: Input to mem_controller from External memory, indicates it's ready for a write.
    wire mem_write_ready_i;
    // mem_read_data_i: Input to mem_controller from External memory, contains data read.
    wire [DATA_BITS-1:0] mem_read_data_i;


    // ====================================================================
    // MODULE INSTANTIATIONS:
    // This section connects instances of the various sub-modules to form
    // the complete miniGPU system. Each instance is commented in detail.
    // ====================================================================

    // 1. Instantiation of dcr (Device Control Register)
    // Module Name: dcr
    // Instance Name: DCR_INST
    // Purpose: Stores the total number of threads for the kernel.
    //          The global 'start' signal is used as a simple write enable.
    dcr DCR_INST (
        .clk(clk),                         // Port: clk           -> Connected to: Global clock
        .reset(reset),                     // Port: reset         -> Connected to: Global reset
        .device_control_write_enable(start), // Port: device_control_write_enable -> Connected to: Global 'start' signal
        .device_control_data(8'd8),          // Port: device_control_data -> Connected to: A constant 8'd8 (8 threads)
        .thread_count(thread_count)          // Port: thread_count  -> Connected to: 'thread_count' internal wire
    );


    // 2. Instantiation of dispatcher
    // Module Name: dispatcher
    // Instance Name: DISPATCHER_INST
    // Purpose: Responsible for scheduling and assigning "blocks" of threads
    //          to the available processing cores, and managing workload distribution.
    dispatcher #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) DISPATCHER_INST (
        .clk(clk),                         // Port: clk            -> Connected to: Global clock
        .reset(reset),                     // Port: reset          -> Connected to: Global reset
        .start(start),                     // Port: start          -> Connected to: Global 'start' signal
        .thread_count(thread_count),       // Port: thread_count   -> Connected to: 'thread_count' wire (from DCR_INST)
        .core_done(core_done),             // Port: core_done      -> Connected to: 'core_done' array wire (from Core instances)
        .core_start(core_start),           // Port: core_start     -> Connected to: 'core_start' array wire (to Core instances)
        .core_reset(core_reset),           // Port: core_reset     -> Connected to: 'core_reset' array wire (to Core instances)
        .core_block_id_flat(core_block_id_flat),// Port: core_block_id_flat -> Connected to: 'core_block_id_flat' wire
        .core_thread_count_flat(core_thread_count_flat),// Port: core_thread_count_flat -> Connected to: 'core_thread_count_flat' wire
        .done(done_kernel_complete)        // Port: done           -> Connected to: 'done_kernel_complete' output port of Toplevel
    );


    // 3. Instantiation of Core Instances
    // This 'generate' block creates multiple instances of the 'core' module (NUM_CORES).
    // Each 'core' acts as an independent processing unit, handling a "block" of threads.
    genvar i; // 'genvar' is used for loop variables within generate blocks
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_instances // Named generate block for clarity in hierarchy
            core #(
                .NUM_THREADS(THREADS_PER_BLOCK),
                .ADDR_BITS(ADDR_BITS),
                .DATA_BITS(DATA_BITS),
                .INSTR_BITS(INSTR_BITS)
            ) CORE_INST (
                .clk(clk),
                .reset(core_reset[i]),
                .core_start(core_start[i]),
                .core_block_id(core_block_id_flat[i*8 +: 8]),
                .core_thread_count(core_thread_count_flat[i*8 +: 8]),
                .core_done(core_done[i]),

                // Connect core's flattened LSU interface to Toplevel's flattened consumer wires
                // These are inputs to the core, coming from the mem_controller.
                .lsu_ready_flat(consumer_ready[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_read_data_flat(consumer_read_data_flat[i*DATA_BITS*THREADS_PER_BLOCK +: DATA_BITS*THREADS_PER_BLOCK]),

                // These are outputs from the core, going to the mem_controller.
                .lsu_read_valid_flat(consumer_read_valid[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_write_valid_flat(consumer_write_valid[i*THREADS_PER_BLOCK +: THREADS_PER_BLOCK]),
                .lsu_read_addr_flat(consumer_read_addr_flat[i*ADDR_BITS*THREADS_PER_BLOCK +: ADDR_BITS*THREADS_PER_BLOCK]),
                .lsu_write_addr_flat(consumer_write_addr_flat[i*ADDR_BITS*THREADS_PER_BLOCK +: ADDR_BITS*THREADS_PER_BLOCK]),
                .lsu_write_data_flat(consumer_write_data_flat[i*DATA_BITS*THREADS_PER_BLOCK +: DATA_BITS*THREADS_PER_BLOCK])
            );
        end
    endgenerate


    // 4. Instantiation of mem_controller (Memory Controller)
    // Module Name: mem_controller
    // Instance Name: MEM_CONTROLLER_INST
    // Purpose: Arbitrates memory requests from all cores' LSUs and interfaces with the external memory module.
    mem_controller #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .NUM_CONSUMERS(NUM_CONSUMERS), // Uses the calculated total number of LSUs
        .NUM_CHANNELS(2)               // Defines how many concurrent memory access channels it can manage
    ) MEM_CONTROLLER_INST (
        .clk(clk),
        .reset(reset),
        // Inputs from LSUs (connected to the flattened consumer wires from core instances)
        .consumer_read_valid(consumer_read_valid),
        .consumer_write_valid(consumer_write_valid),
        .consumer_read_address(consumer_read_addr_flat),
        .consumer_write_address(consumer_write_addr_flat),
        .consumer_write_data(consumer_write_data_flat),
        // Outputs to LSUs (connected to the flattened consumer wires to core instances)
        .consumer_ready(consumer_ready),
        .consumer_read_data(consumer_read_data_flat),
        // Inputs from external memory module (from 'memory.v')
        .mem_read_ready(mem_read_ready_i),
        .mem_write_ready(mem_write_ready_i),
        .mem_read_data(mem_read_data_i),
        // Outputs to external memory module (to 'memory.v')
        .mem_read_valid(mem_read_valid_o),
        .mem_write_valid(mem_write_valid_o),
        .mem_read_address(mem_read_address_o),
        .mem_write_address(mem_write_address_o),
        .mem_write_data(mem_write_data_o)
    );


    // 5. Instantiation of external memory module
    // Module Name: memory
    // Instance Name: MEMORY_INST
    // Purpose: Acts as the main data storage for the miniGPU.
    //          It's a behavioral model of a simple RAM that responds to
    //          read/write requests from the MemoryController.
    memory #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS)
    ) MEMORY_INST (
        .clk(clk),
        // Inputs from MemoryController
        .mem_read_valid(mem_read_valid_o),
        .mem_write_valid(mem_write_valid_o),
        .mem_read_address(mem_read_address_o),
        .mem_write_address(mem_write_address_o),
        .mem_write_data(mem_write_data_o),
        // Outputs to MemoryController
        .mem_read_ready(mem_read_ready_i),
        .mem_write_ready(mem_write_ready_i),
        .mem_read_data(mem_read_data_i)
    );

endmodule
