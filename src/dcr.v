// dcr.v
// Device Control Register module.
// A simple synchronous register that stores the total number of threads
// for the miniGPU kernel. This value is read by the Dispatcher.

module dcr ( // Module name is lowercase: dcr
    input clk,                         // Clock signal (for synchronous operation)
    input reset,                       // Asynchronous reset signal
    input device_control_write_enable, // Control signal: When high, enables writing 'device_control_data'
    input [7:0] device_control_data,   // 8-bit data input to be stored (e.g., total threads)
    output reg [7:0] thread_count      // Output: The stored total thread count
);

    // Internal register to hold the thread count value.
    // This 'reg' will store the data across clock cycles.
    reg [7:0] internal_thread_count_reg;

    // This 'always' block describes the sequential (clocked) behavior of the register.
    // It is sensitive to both the positive edge of the clock and the positive edge of reset.
    always @(posedge clk or posedge reset) begin : dcr_reg_logic // Named block for Verilog-2001 compatibility
        if (reset) begin
            // Asynchronous reset: If 'reset' is high, immediately clear the register.
            internal_thread_count_reg <= 8'b0;
            thread_count <= 8'b0; // Ensure output is also reset
        end else begin
            // Synchronous write: If not in reset and 'device_control_write_enable' is high,
            // update the internal register with the new 'device_control_data' on the clock edge.
            if (device_control_write_enable) begin
                internal_thread_count_reg <= device_control_data;
            end
            // The 'thread_count' output always reflects the current value of the internal register.
            thread_count <= internal_thread_count_reg;
        end
    end

endmodule
