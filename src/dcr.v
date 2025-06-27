module DeviceControlRegister (
    input clk, reset,                    // Clock and synchronous reset
    input device_control_write_enable,   // Enables writing to register
    input [7:0] device_control_data,     // 8-bit data to store
    output reg [7:0] thread_count        // Output reflecting stored value
);
    // Internal register storing thread count
    reg [7:0] internal_reg;
    
    always @(posedge clk) begin
        if (reset) begin
            // Clears register on reset
            internal_reg <= 8'b0;
            thread_count <= 8'b0;
        end else if (device_control_write_enable) begin
            // Updates register with input data
            internal_reg <= device_control_data;
            thread_count <= device_control_data;
        end
    end
endmodule
