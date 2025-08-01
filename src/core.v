// core.v
// Represents a single processing core in the miniGPU.

module core #(
    parameter NUM_THREADS = 4,
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8,
    parameter INSTR_BITS = 16
)(
    input clk,
    input reset,
    input core_start,
    input [7:0] core_block_id,
    input [7:0] core_thread_count,
    output core_done,

    input [NUM_THREADS-1:0] lsu_ready_flat,
    input [(NUM_THREADS*DATA_BITS)-1:0] lsu_read_data_flat,

    output [NUM_THREADS-1:0] lsu_read_valid_flat,
    output [NUM_THREADS-1:0] lsu_write_valid_flat,
    output [(NUM_THREADS*ADDR_BITS)-1:0] lsu_read_addr_flat,
    output [(NUM_THREADS*ADDR_BITS)-1:0] lsu_write_addr_flat,
    output [(NUM_THREADS*DATA_BITS)-1:0] lsu_write_data_flat
);

    // ... (rest of core.v declarations remain the same) ...
    wire [2:0] core_state;
    wire [INSTR_BITS-1:0] instruction;

    wire [3:0] rd_addr;
    wire [3:0] rs_addr;
    wire [3:0] rt_addr;
    wire [7:0] imm8;
    wire [2:0] decoded_nzp;
    wire reg_write_enable;
    wire [1:0] reg_input_mux;
    wire mem_read_enable;
    wire mem_write_enable;
    wire nzp_write_enable;
    wire [1:0] alu_control;
    wire alu_output_mux;
    wire next_pc_mux;
    wire decoded_ret;

    wire [(NUM_THREADS*DATA_BITS)-1:0] rs_data_flat;
    wire [(NUM_THREADS*DATA_BITS)-1:0] rt_data_flat;
    wire [(NUM_THREADS*DATA_BITS)-1:0] alu_out_flat;

    // === CRUCIAL PC FIX DECLARATION ===
    // This wire will collect the 'next_pc' outputs from all pc_nzp instances.
    wire [(NUM_THREADS*ADDR_BITS)-1:0] next_pc_from_pc_nzp_flat;
    // The 'current_pc_flat' is now driven ONLY by 'next_pc_from_pc_nzp_flat'.
    wire [(NUM_THREADS*ADDR_BITS)-1:0] current_pc_flat;
    // Connect the next PC from pc_nzp units to the current PC for the next fetch cycle.
    assign current_pc_flat = next_pc_from_pc_nzp_flat;


    wire [(NUM_THREADS*3)-1:0] nzp_flags_flat;

    wire [(NUM_THREADS*DATA_BITS)-1:0] lsu_out_flat;
    wire [(NUM_THREADS*2)-1:0] lsu_state_flat_internal;

    wire [7:0] block_id;
    wire [7:0] threads_per_block;
    wire [(NUM_THREADS*8)-1:0] thread_id_flat;

    wire [DATA_BITS-1:0] write_back_data [0:NUM_THREADS-1];

    genvar j_mux;
    generate
        for (j_mux = 0; j_mux < NUM_THREADS; j_mux = j_mux + 1) begin : write_back_muxes
            assign write_back_data[j_mux] = (reg_input_mux == 2'b00) ? alu_out_flat[j_mux*DATA_BITS +: DATA_BITS] :
                                            (reg_input_mux == 2'b01) ? lsu_out_flat[j_mux*DATA_BITS +: DATA_BITS] :
                                            imm8;
        end
    endgenerate

    wire [0:0] lsu_ready_internal [0:NUM_THREADS-1];
    wire [DATA_BITS-1:0] lsu_read_data_internal [0:NUM_THREADS-1];

    genvar j_input_unpack;
    generate
        for (j_input_unpack = 0; j_input_unpack < NUM_THREADS; j_input_unpack = j_input_unpack + 1) begin : input_unpack
            assign lsu_ready_internal[j_input_unpack]    = lsu_ready_flat[j_input_unpack];
            assign lsu_read_data_internal[j_input_unpack] = lsu_read_data_flat[j_input_unpack*DATA_BITS +: DATA_BITS];
        end
    endgenerate

    wire [0:0] lsu_read_valid_internal [0:NUM_THREADS-1];
    wire [0:0] lsu_write_valid_internal [0:NUM_THREADS-1];
    wire [ADDR_BITS-1:0] lsu_read_addr_internal [0:NUM_THREADS-1];
    wire [ADDR_BITS-1:0] lsu_write_addr_internal [0:NUM_THREADS-1];
    wire [DATA_BITS-1:0] lsu_write_data_internal [0:NUM_THREADS-1];

    genvar j_output_pack;
    generate
        for (j_output_pack = 0; j_output_pack < NUM_THREADS; j_output_pack = j_output_pack + 1) begin : output_pack
            assign lsu_read_valid_flat[j_output_pack]  = lsu_read_valid_internal[j_output_pack];
            assign lsu_write_valid_flat[j_output_pack] = lsu_write_valid_internal[j_output_pack];
            assign lsu_read_addr_flat[j_output_pack*ADDR_BITS +: ADDR_BITS]   = lsu_read_addr_internal[j_output_pack];
            assign lsu_write_addr_flat[j_output_pack*ADDR_BITS +: ADDR_BITS]  = lsu_write_addr_internal[j_output_pack];
            assign lsu_write_data_flat[j_output_pack*DATA_BITS +: DATA_BITS] = lsu_write_data_internal[j_output_pack];
        end
    endgenerate


    // ====================================================================
    // Module Instantiations within the Core
    // ====================================================================

    // 1. Scheduler Instance
    scheduler #(
        .NUM_THREADS(NUM_THREADS)
    ) SCHED_INST (
        .clk(clk),
        .reset(reset),
        .core_start(core_start),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .lsu_state_flat(lsu_state_flat_internal),
        .decoded_ret(decoded_ret),
        .core_state(core_state),
        .core_done(core_done),
        .block_id(block_id),
        .threads_per_block(threads_per_block),
        .thread_id_flat(thread_id_flat)
    );

    // 2. Fetcher Instance
    fetcher #(
        .NUM_THREADS(NUM_THREADS),
        .ADDR_BITS(ADDR_BITS),
        .INSTR_BITS(INSTR_BITS)
    ) FETCH_INST (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .current_pc_flat(current_pc_flat),   // Input to fetcher (from pc_nzp outputs)
        .instruction(instruction),
        // === CRUCIAL PC FIX ===
        // Fetcher's pc_out_flat is no longer connected to current_pc_flat.
        // It's simply a passthrough of its input, so we don't connect its output directly.
        // Or if its meant to be an output for monitoring, it needs to be renamed or its behavior adjusted.
        // For simplicity, we can remove the connection here as fetcher doesn't *drive* current_pc_flat.
        // If fetcher.v's pc_out_flat is indeed just an input passthrough, then connecting it to an output is problematic.
        // Let's assume fetcher's pc_out_flat is a *passthrough of its input* for *monitoring* purposes,
        // and current_pc_flat is the *source* for both fetcher's input and pc_nzp's input.
        // The *driver* for current_pc_flat must be next_pc_from_pc_nzp_flat.
        .pc_out_flat() // Disconnect this, as Fetcher should not drive current_pc_flat
                        // If pc_out_flat in fetcher is truly an output, we need a new wire for it.
                        // However, based on the previous fetcher.v code, its 'pc' output was
                        // assigned 'current_pc_internal'. The 'current_pc_flat' is the *source*
                        // for Fetcher's input current_pc_internal, and it's also the source for pc_nzp.
                        // So, pc_out_flat from fetcher should *not* be connected back to current_pc_flat.
                        // It should be driven by current_pc_flat (which is driven by next_pc_from_pc_nzp_flat).
    );

    // 3. Decoder Instance
    decoder DEC_INST (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .instruction(instruction),
        .rd_addr(rd_addr),
        .rs_addr(rs_addr),
        .rt_addr(rt_addr),
        .imm8(imm8),
        .decoded_nzp(decoded_nzp),
        .reg_write_enable(reg_write_enable),
        .mem_read_enable(mem_read_enable),
        .mem_write_enable(mem_write_enable),
        .nzp_write_enable(nzp_write_enable),
        .decoded_ret(decoded_ret),
        .alu_control(alu_control),
        .reg_input_mux(reg_input_mux),
        .alu_output_mux(alu_output_mux),
        .next_pc_mux(next_pc_mux)
    );

    // 4. Thread Instances (using generate block for NUM_THREADS parallel pipelines)
    genvar j_thread;
    generate
        for (j_thread = 0; j_thread < NUM_THREADS; j_thread = j_thread + 1) begin : thread_pipelines
            wire [DATA_BITS-1:0] rs_data;
            wire [DATA_BITS-1:0] rt_data;
            wire [DATA_BITS-1:0] alu_out;
            wire [DATA_BITS-1:0] lsu_out;
            wire [1:0] lsu_state;

            wire [7:0] current_thread_id;
            assign current_thread_id = thread_id_flat[j_thread*8 +: 8];


            // 4.1. RegisterFile Instance (per thread)
            register_file RF_INST (
                .clk(clk),
                .reset(reset),
                .enable(1'b1),
                .core_state(core_state),
                .rd_addr(rd_addr),
                .rs_addr(rs_addr),
                .rt_addr(rt_addr),
                .data_in(write_back_data[j_thread]),
                .reg_input_mux(reg_input_mux),
                .reg_write_enable(reg_write_enable),
                .block_id(block_id),
                .thread_id(current_thread_id),
                .threads_per_block(threads_per_block),
                .rs_data(rs_data),
                .rt_data(rt_data)
            );

            // 4.2. ALU Instance (per thread)
            alu ALU_INST (
                .clk(clk),
                .reset(reset),
                .enable(1'b1),
                .core_state(core_state),
                .decoded_alu_arithmetic_mux(alu_control),
                .decoded_alu_output_mux(alu_output_mux),
                .rs(rs_data),
                .rt(rt_data),
                .alu_out(alu_out)
            );

            // 4.3. PC_NZP Instance (per thread)
            pc_nzp PCNZP_INST (
                .clk(clk),
                .reset(reset),
                .enable(1'b1),
                .core_state(core_state),
                .current_pc(current_pc_flat[j_thread*ADDR_BITS +: ADDR_BITS]), // Input PC to this thread's PC_NZP
                .alu_out(alu_out),
                .imm8(imm8),
                .decoded_nzp(decoded_nzp),
                .nzp_write_enable(nzp_write_enable),
                .next_pc_mux(next_pc_mux),
                // === CRUCIAL PC FIX ===
                // Output 'next_pc' from PC_NZP drives the new 'next_pc_from_pc_nzp_flat' wire.
                .next_pc(next_pc_from_pc_nzp_flat[j_thread*ADDR_BITS +: ADDR_BITS]),
                .nzp_flags(nzp_flags_flat[j_thread*3 +: 3])
            );

            // 4.4. LSU Instance (per thread)
            lsu LSU_INST (
                .clk(clk),
                .reset(reset),
                .enable(1'b1),
                .core_state(core_state),
                .decoded_mem_read_enable(mem_read_enable),
                .decoded_mem_write_enable(mem_write_enable),
                .rs(rs_data),
                .rt(rt_data),
                .mem_read_ready(lsu_ready_internal[j_thread]),
                .mem_write_ready(lsu_ready_internal[j_thread]),
                .mem_read_data(lsu_read_data_internal[j_thread]),
                .lsu_out(lsu_out),
                .lsu_state(lsu_state),
                .mem_read_valid(lsu_read_valid_internal[j_thread]),
                .mem_write_valid(lsu_write_valid_internal[j_thread]),
                .mem_read_address(lsu_read_addr_internal[j_thread]),
                .mem_write_address(lsu_write_addr_internal[j_thread]),
                .mem_write_data(lsu_write_data_internal[j_thread])
            );

            // Map thread-specific outputs to flattened core-level wires
            assign rs_data_flat[j_thread*DATA_BITS +: DATA_BITS] = rs_data;
            assign rt_data_flat[j_thread*DATA_BITS +: DATA_BITS] = rt_data;
            assign alu_out_flat[j_thread*DATA_BITS +: DATA_BITS] = alu_out;
            assign lsu_out_flat[j_thread*DATA_BITS +: DATA_BITS] = lsu_out;
            assign lsu_state_flat_internal[j_thread*2 +: 2]      = lsu_state;

        end // end for loop : thread_pipelines
    endgenerate

endmodule
