// memory.v
// This module simulates the main memory (RAM) of the miniGPU system.
// It stores program data and responds to read/write requests from the MemoryController.

module memory #(
    parameter ADDR_BITS = 8, // Parameter: Address width (e.g., 8 bits for 2^8 = 256 locations)
    parameter DATA_BITS = 8  // Parameter: Data width (e.g., 8 bits for byte-addressable data)
)(
    input clk,

    // Inputs from MemoryController (memory requests)
    input mem_read_valid,                // High when MemoryController requests a read
    input mem_write_valid,               // High when MemoryController requests a write
    input [ADDR_BITS-1:0] mem_read_address,   // Address for the read request
    input [ADDR_BITS-1:0] mem_write_address,  // Address for the write request
    input [DATA_BITS-1:0] mem_write_data,     // Data to be written to memory

    // Outputs to MemoryController (memory responses)
    output reg mem_read_ready,           // Indicates memory is ready to accept a read request
                                         // (Always high in this simple model, implying single-cycle access)
    output reg mem_write_ready,          // Indicates memory is ready to accept a write request
                                         // (Always high in this my model)
    output reg [DATA_BITS-1:0] mem_read_data // Data read from memory (combinational output)
);

    reg [DATA_BITS-1:0] memory_array [0:2**ADDR_BITS-1];

    integer j_loop;

    initial begin : mem_init_block // Named block for Verilog-2001 compatibility
        // $display("[%0t] MEMORY: Initializing Memory...", $time); // Commented out for synthesis

        // Fill memory with ascending values as a default, useful for debugging
        // if unexpected addresses are accessed.
        for (j_loop = 0; j_loop < (2**ADDR_BITS); j_loop = j_loop + 1) begin
            memory_array[j_loop] = j_loop; // Stores value 'i' at address 'i'
        end

        memory_array[8'd10] = 8'd5;  // Address 10 will contain value 5
        memory_array[8'd11] = 8'd7;  // Address 11 will contain value 7
        memory_array[8'd12] = 8'd0;  // Address 12 is a placeholder for the kernel's result (5+7=12)

        // For NUM_THREADS=4, the kernel also accesses 10+thread_id, 11+thread_id, 12+thread_id
        // Thread 0: 10, 11, 12
        // Thread 1: 11, 12, 13
        // Thread 2: 12, 13, 14
        // Thread 3: 13, 14, 15

        // So, initialize data for other threads' inputs as well:
        memory_array[8'd10 + 1] = 8'd6; // T1's first operand from addr 11
        memory_array[8'd11 + 1] = 8'd8; // T1's second operand from addr 12
        // Ensure initial results placeholder for other threads
        memory_array[8'd12 + 1] = 8'd0; // T1's result addr 13

        memory_array[8'd10 + 2] = 8'd9; // T2's first operand from addr 12
        memory_array[8'd11 + 2] = 8'd2; // T2's second operand from addr 13
        memory_array[8'd12 + 2] = 8'd0; // T2's result addr 14

        memory_array[8'd10 + 3] = 8'd3; // T3's first operand from addr 13
        memory_array[8'd11 + 3] = 8'd4; // T3's second operand from addr 14
        memory_array[8'd12 + 3] = 8'd0; // T3's result addr 15

        // Set memory to be always ready for requests in this simple model.
        mem_read_ready <= 1'b1;
        mem_write_ready <= 1'b1;

        // $display("[%0t] MEMORY: Initialization Complete.", $time); // Commented out for synthesis
    end

    always @(*) begin 
        mem_read_data = memory_array[mem_read_address];
    end

    always @(posedge clk) begin : mem_write_proc // Named block for Verilog-2001 compatibility
        if (mem_write_valid) begin
            memory_array[mem_write_address] <= mem_write_data; // Non-blocking assignment for reg array element
            // $display("[%0t] MEMORY: Wrote %0d to address %0d", $time, mem_write_data, mem_write_address); // Commented out for synthesis
        end
    end

endmodule
