`timescale 1ns / 1ps

module tb_toplevel;
    reg clk, reset, start;
    reg [7:0] device_control_data;
    reg device_control_write_enable;
    wire done;

    // Instantiate the toplevel
    toplevel uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk; // 100MHz clock

    initial begin
        $display("==== miniGPU Top-Level Testbench ====");
        $dumpfile("toplevel.vcd"); // For waveform viewing
        $dumpvars(0, tb_toplevel);

        clk = 0;
        reset = 1;
        start = 0;
        device_control_write_enable = 0;
        device_control_data = 8'd0;

        // Reset pulse
        #20;
        reset = 0;

        // Set thread count in DCR to 4 (one block)
        #10;
        device_control_write_enable = 1;
        device_control_data = 8'd4;
        #10;
        device_control_write_enable = 0;

        // Trigger kernel start
        #10;
        start = 1;
        #10;
        start = 0;

        // Wait for execution to complete
        wait (done == 1);
        #20;

        $display("Execution completed.");
        $finish;
    end
endmodule