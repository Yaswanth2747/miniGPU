`timescale 1ns / 1ps

module tb_core;

    // ====================================================================
    // Testbench Parameters (Matching Toplevel defaults)
    // ====================================================================
    parameter NUM_THREADS = 4;
    parameter ADDR_BITS = 8;
    parameter DATA_BITS = 8;
    parameter INSTR_BITS = 16;

    // ====================================================================
    // Testbench Signals (to connect to the 'core' module's ports)
    // ====================================================================
    reg clk;
    reg reset;
    reg core_start;
    reg [7:0] core_block_id;
    reg [7:0] core_thread_count;
    wire core_done; // Output from the core: signals block completion

    reg [NUM_THREADS-1:0] lsu_ready_flat;
    reg [(NUM_THREADS*DATA_BITS)-1:0] lsu_read_data_flat;

    wire [NUM_THREADS-1:0] lsu_read_valid_flat;
    wire [NUM_THREADS-1:0] lsu_write_valid_flat;
    wire [(NUM_THREADS*ADDR_BITS)-1:0] lsu_read_addr_flat;
    wire [(NUM_THREADS*ADDR_BITS)-1:0] lsu_write_addr_flat;
    wire [(NUM_THREADS*DATA_BITS)-1:0] lsu_write_data_flat;


    // ====================================================================
    // Instantiate the Design Under Test (DUT) - Our 'core.v' module
    // ====================================================================
    core #(
        .NUM_THREADS(NUM_THREADS),
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .INSTR_BITS(INSTR_BITS)
    ) CORE_DUT (
        .clk(clk),
        .reset(reset),
        .core_start(core_start),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .core_done(core_done),

        .lsu_ready_flat(lsu_ready_flat),
        .lsu_read_data_flat(lsu_read_data_flat),

        .lsu_read_valid_flat(lsu_read_valid_flat),
        .lsu_write_valid_flat(lsu_write_valid_flat),
        .lsu_read_addr_flat(lsu_read_addr_flat),
        .lsu_write_addr_flat(lsu_write_addr_flat),
        .lsu_write_data_flat(lsu_write_data_flat)
    );


    // ====================================================================
    // Clock Generation
    // ====================================================================
    always #5 clk = ~clk;


    // ====================================================================
    // Test Scenario (Stimulus Generation)
    // ====================================================================
    initial begin : test_stimulus // Named block for Verilog-2001 compatibility
        // Local variable for timeout mechanism
        reg simulation_finished_by_done; // Flag to indicate if core_done finished simulation

        // Initialize all inputs to a known state at time 0.
        clk = 1'b0;
        reset = 1'b1;
        core_start = 1'b0;
        core_block_id = 8'h00;
        core_thread_count = NUM_THREADS;

        lsu_ready_flat = {NUM_THREADS{1'b1}};
        lsu_read_data_flat = {(NUM_THREADS*DATA_BITS){1'b0}};

        simulation_finished_by_done = 1'b0; // Initialize flag

        $display("[%0t] TB: Starting 'core' testbench simulation...", $time);

        #20; // Wait 20ns (2 clock cycles)
        reset = 1'b0;
        $display("[%0t] TB: Reset de-asserted for core.", $time);

        #10; // Allow some time for core to settle in IDLE state.

        core_block_id = 8'd0;
        core_thread_count = 8'd4;
        $display("[%0t] TB: Asserting core_start for Block %0d with %0d threads...", $time, core_block_id, core_thread_count);
        core_start = 1'b1;
        #10;
        core_start = 1'b0;

        // --- VERILOG-2001 COMPLIANT TIMEOUT LOGIC ---
        // This 'wait' statement will halt this initial block until core_done becomes 1.
        // If core_done does not become 1, this block will wait indefinitely.
        wait(core_done == 1'b1);
        $display("[%0t] TB: core_done asserted. Core completed its block.", $time);
        simulation_finished_by_done = 1'b1; // Set flag when core_done asserts

        #20; // Small delay to observe final states
        $display("[%0t] TB: Simulation finished (Core Done).", $time);
        $finish;
    end

    // ====================================================================
    // Secondary Initial Block for Simulation Timeout (Verilog-2001 compatible)
    // This block will force a simulation finish after a maximum time,
    // in case the main test_stimulus block gets stuck.
    // ====================================================================
    initial begin : timeout_monitor // Named block for Verilog-2001 compatibility
        parameter MAX_SIM_TIME = 1000; // Define maximum simulation time (1000ns)

        #MAX_SIM_TIME; // Wait for the maximum simulation time

        // Check if the simulation was already finished by the 'core_done' signal.
        // We need to access the 'simulation_finished_by_done' flag from the other initial block.
        // For strict Verilog-2001, inter-initial block communication requires a little care.
        // Simplest for now: if core_done is still 0 after MAX_SIM_TIME, then it's a timeout.
        if (CORE_DUT.core_done == 1'b0) begin
            $display("[%0t] TB: Simulation timeout! core_done did NOT assert within %0dns.", $time, MAX_SIM_TIME);
            $finish; // Force finish due to timeout
        end
        // If core_done was already 1, the other initial block would have called $finish.
    end


    // ====================================================================
    // Waveform Dumping
    // ====================================================================
    initial begin
        $dumpfile("core_tb_waveform.vcd");
        $dumpvars(0, core_tb);
    end

    // ====================================================================
    // Monitoring and Debugging ($monitor provides textual trace)
    // ====================================================================
    initial begin
        $monitor("Time=%0t | Core_State=%b | Core_Done=%b | PC_T0=%h | Instr_Fetched=%h | ALU_Out_T0=%h | LSU_State_T0=%b | RF_R0_T0=%h | RF_R14_T0=%h | Mem_W_Addr_T0=%h | Mem_W_Data_T0=%h | Mem_W_Valid_T0=%b",
                 $time,
                 CORE_DUT.core_state,
                 CORE_DUT.core_done,
                 CORE_DUT.current_pc_flat[0*ADDR_BITS +: ADDR_BITS],
                 CORE_DUT.instruction,
                 CORE_DUT.alu_out_flat[0*DATA_BITS +: DATA_BITS],
                 CORE_DUT.lsu_state_flat_internal[0*2 +: 2],
                 CORE_DUT.thread_pipelines[0].RF_INST.registers[0],
                 CORE_DUT.thread_pipelines[0].RF_INST.registers[14],
                 CORE_DUT.lsu_write_addr_flat[0*ADDR_BITS +: ADDR_BITS],
                 CORE_DUT.lsu_write_data_flat[0*DATA_BITS +: DATA_BITS],
                 CORE_DUT.lsu_write_valid_flat[0]
                 );
    end

endmodule
