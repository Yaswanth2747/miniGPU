// register_file.v
// General Purpose Register File for a single miniGPU thread.
// Provides fast storage for 16 8-bit registers.
// Supports two simultaneous reads and one synchronous write.

module register_file ( // Module name is lowercase: register_file
    input clk,                           
    input reset,                         
    input enable,                        // Enable signal for this Register File instance (from core)
    input [2:0] core_state,              // Current pipeline state from Scheduler (e.g., 3'b011 = REQUEST)
                                         // Register writes typically occur based on the 'REQUEST' or 'UPDATE' stage.

    // Write Port Inputs
    input [3:0] rd_addr,                 // Destination Register Address (4 bits for 16 registers)
    input [7:0] data_in,                 // Data to be written to the destination register
    input [1:0] reg_input_mux,           // Mux select for 'data_in' source from Decoder:
                                         //   2'b00: ALU output
                                         //   2'b01: LSU output (read data from memory)
                                         //   2'b10: Immediate value (from instruction)
    input reg_write_enable,              // Enable signal for writing to the destination register

    // Read Port Inputs (Addresses)
    input [3:0] rs_addr,                 // Source Register 1 Address
    input [3:0] rt_addr,                 // Source Register 2 Address

    // Inputs for Reserved Registers (Initialized once by Scheduler)
    input [7:0] block_id,                // Block ID (for R13)
    input [7:0] thread_id,               // Thread ID within the block (for R14)
    input [7:0] threads_per_block,       // Total threads in the block (for R15)

    output [7:0] rs_data,                // Data read from Source Register 1
    output [7:0] rt_data                 // Data read from Source Register 2
);

    reg [7:0] registers [0:15];

    integer i_loop;

    assign rs_data = registers[rs_addr];
    assign rt_data = registers[rt_addr];

    always @(posedge clk or posedge reset) begin : register_file_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // On asynchronous reset, clear all 16 registers to 0.
            for (i_loop = 0; i_loop < 16; i_loop = i_loop + 1) begin
                registers[i_loop] <= 8'b0;
            end
            // Initialize reserved registers with their context-specific values.
            // R13: block_id (which block this core is processing)
            registers[13] <= block_id;
            // R14: thread_id (unique ID for this specific thread within its block)
            registers[14] <= thread_id;
            // R15: threads_per_block (total number of threads in this core's block)
            registers[15] <= threads_per_block;
        end
        else if (enable && core_state == 3'b011 && reg_write_enable) begin

            case (reg_input_mux)
                2'b00, 2'b01, 2'b10: begin // Covers ALU output, LSU output, or Immediate data sources
                    if (rd_addr != 4'd13 && rd_addr != 4'd14 && rd_addr != 4'd15) begin
                        registers[rd_addr] <= data_in; // Write data to the destination register
                    end
                end
                default: begin
                    // No action for undefined 'reg_input_mux' values (should not happen with proper decoding).
                end
            endcase
        end
    end

endmodule
