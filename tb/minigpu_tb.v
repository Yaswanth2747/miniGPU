// Testbench for the entire miniGPU system (Toplevel.v).
// This testbench provides the global clock, reset, and start signals.
// It monitors key signals across the full hierarchy to verify kernel execution
// including core dispatch, memory access, and overall completion.

`timescale 1ns / 1ps // (1ns for delay, 1ps for precision)

module minigpu_tb;

    // ====================================================================
    // Testbench Parameters (Matching Toplevel defaults for the DUT)
    // ====================================================================
    parameter NUM_CORES = 2;           // Number of cores in the instantiated miniGPU
    parameter THREADS_PER_BLOCK = 4;   // Threads per block in the instantiated miniGPU
    parameter ADDR_BITS = 8;           // Address bus width
    parameter DATA_BITS = 8;           // Data bus width
    parameter INSTR_BITS = 16;         // Instruction word width

    // ====================================================================
    // Testbench Signals (to connect to the Toplevel.v module's ports)
    // ====================================================================
    reg clk;   // Global clock signal
    reg reset; // Global asynchronous reset signal
    reg start; // Global start signal to initiate kernel execution

    // This signal indicates when the entire kernel execution is complete.
    // It's the 'done_kernel_complete' output from the Toplevel DUT.
    wire done_kernel_complete;

    // ====================================================================
    // Instantiate the Design Under Test (DUT) - Our 'Toplevel.v' miniGPU
    // ====================================================================
    Toplevel #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .INSTR_BITS(INSTR_BITS)
    ) MINI_GPU_DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done_kernel_complete(done_kernel_complete) // Connect to Toplevel's output port
    );


    // ====================================================================
    // Clock Generation
    // ====================================================================
    // Generates a clock with a 10ns period (5ns high, 5ns low), 100 MHz.
    always #5 clk = ~clk;


    // ====================================================================
    // Test Scenario (Stimulus Generation)
    // This 'initial' block provides the main sequence of events.
    // ====================================================================
    initial begin : test_stimulus // Named block for Verilog-2001 compatibility
        // Initialize all inputs to a known state at time 0.
        clk = 1'b0;
        reset = 1'b1; // Assert global reset
        start = 1'b0;

        $display("[%0t] TB: Starting full miniGPU system testbench simulation...", $time);

        // Apply global reset for a few clock cycles to ensure proper initialization of all modules.
        #20; // Wait 20ns (2 clock cycles)
        reset = 1'b0; // De-assert global reset
        $display("[%0t] TB: Global reset de-asserted.", $time);

        // Allow some time for all modules (Dispatcher, Cores, etc.) to settle in IDLE state.
        #30; // Wait 30ns (3 clock cycles)

        // Assert the 'start' signal to trigger the kernel execution.
        // This will initiate DCR, which then triggers Dispatcher.
        $display("[%0t] TB: Asserting global 'start' signal to miniGPU...", $time);
        start = 1'b1;
        #10; // Hold 'start' high for one clock cycle
        start = 1'b0; // De-assert 'start'

        // --- VERILOG-2001 COMPLIANT TIMEOUT LOGIC (Part 1) ---
        // This 'wait' statement will halt THIS initial block until done_kernel_complete becomes 1.
        wait(done_kernel_complete == 1'b1);
        $display("[%0t] TB: !!! KERNEL COMPLETED !!! The entire miniGPU kernel execution is DONE.", $time);

        #20; // Small delay to observe final states
        $display("[%0t] TB: Simulation finished (Kernel Done).", $time);
        $finish; // End simulation (if kernel completes)
    end


    // ====================================================================
    // Secondary Initial Block for Simulation Timeout (Verilog-2001 compatible)
    // This block runs concurrently with 'test_stimulus' and will force a simulation finish
    // after a maximum time, in case the main kernel execution gets stuck.
    // ====================================================================
    initial begin : timeout_monitor // Named block for Verilog-2001 compatibility
        parameter MAX_SIM_TIME_S = 2000; // Define maximum simulation time in ns (2000ns)

        #MAX_SIM_TIME_S; // Wait for the maximum simulation time

        // Check if the simulation was already finished by the 'done_kernel_complete' signal.
        // If 'done_kernel_complete' is still 0 after MAX_SIM_TIME_S, it means a timeout occurred.
        if (done_kernel_complete == 1'b0) begin // Directly access the port's wire
            $display("[%0t] TB: Simulation TIMEOUT! Kernel did NOT complete within %0dns.", $time, MAX_SIM_TIME_S);
            $finish; // Force finish due to timeout
        end
    end


    // ====================================================================
    // Waveform Dumping
    // ====================================================================
    initial begin
        $dumpfile("minigpu_tb_waveform.vcd");
        $dumpvars(0, minigpu_tb);
    end

    // ====================================================================
    // Monitoring and Debugging ($monitor provides textual trace)
    // --- SIMPLIFIED FOR ROBUSTNESS ---
    // ====================================================================
    initial begin
        // Only monitor top-level and immediate sub-module signals for initial debug.
        // For deep hierarchy, use the waveform viewer (VCD).
        $monitor("Time=%0t | START=%b | RESET=%b | DONE_KERN=%b | Total_Threads=%0d | Disp_Blocks_Dispatched=%0d | Disp_Blocks_Done=%0d | Mem_Rd_Valid=%b | Mem_Wr_Valid=%b | Mem_Wr_Addr=%h | Mem_Wr_Data=%h | Mem_W_Valid=%b",
                 $time,
                 start,
                 reset,
                 done_kernel_complete, // Directly connect to the output port
                 MINI_GPU_DUT.DCR_INST.thread_count,
                 MINI_GPU_DUT.DISPATCHER_INST.blocks_dispatched,
                 MINI_GPU_DUT.DISPATCHER_INST.blocks_done,
                 MINI_GPU_DUT.mem_read_valid_o,      // Toplevel wire from MemController
                 MINI_GPU_DUT.mem_write_valid_o,     // Toplevel wire from MemController
                 MINI_GPU_DUT.mem_write_address_o,   // Toplevel wire from MemController
                 MINI_GPU_DUT.mem_write_data_o,      // Toplevel wire from MemController
                 MINI_GPU_DUT.mem_write_valid_o      // Toplevel wire from MemController
                 );
    end

endmodule
