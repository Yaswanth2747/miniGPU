module core #( // Adding a little a flexibilty to call miniGPU a Multicore GPU.
    parameter NUM_THREADS = 4
)(
    input clk, reset,
    input core_start,
    input [7:0] core_block_id,
    input [7:0] core_thread_count,
    output core_done,

    // Memory Controller interface
    output [NUM_THREADS-1:0] lsu_read_valid,
    output [NUM_THREADS-1:0] lsu_write_valid,
    output [NUM_THREADS-1:0][7:0] lsu_read_addr,
    output [NUM_THREADS-1:0][7:0] lsu_write_addr,
    output [NUM_THREADS-1:0][7:0] lsu_write_data,
    input [NUM_THREADS-1:0] lsu_ready,
    input [NUM_THREADS-1:0][7:0] lsu_read_data
);
    wire [2:0] core_state;
    wire [1:0] lsu_state [0:NUM_THREADS-1];
    wire [7:0] thread_id [0:NUM_THREADS-1];
    wire [7:0] rs [0:NUM_THREADS-1], rt [0:NUM_THREADS-1], alu_out [0:NUM_THREADS-1], lsu_out [0:NUM_THREADS-1], pc [0:NUM_THREADS-1];
    wire [2:0] nzp [0:NUM_THREADS-1];
    wire [7:0] imm8;
    wire [3:0] rd_addr, rs_addr, rt_addr;
    wire reg_we, mem_re, mem_we, nzp_we, alu_out_mux, next_pc_mux, decoded_ret;
    wire [1:0] alu_control, reg_input_mux;
    wire [15:0] instruction;

    wire [7:0] current_pc [0:NUM_THREADS-1];

    // ========== Scheduler ==========
    scheduler #(.NUM_THREADS(NUM_THREADS)) SCHED (
        .clk(clk), .reset(reset),
        .core_start(core_start),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .lsu_state(lsu_state),
        .decoded_ret(decoded_ret),
        .core_state(core_state),
        .core_done(core_done),
        .block_id(block_id),
        .threads_per_block(threads_per_block),
        .thread_id(thread_id)
    );

    // ========== Fetcher ==========
    Fetcher #(.NUM_THREADS(NUM_THREADS)) FETCH (
        .clk(clk), .reset(reset),
        .core_state(core_state),
        .current_pc(current_pc),
        .instruction(instruction),
        .pc(pc)
    );

    // ========== Decoder ==========
    Decoder DEC (
        .clk(clk), .reset(reset),
        .core_state(core_state),
        .instruction(instruction),
        .rd_addr(rd_addr),
        .rs_addr(rs_addr),
        .rt_addr(rt_addr),
        .imm8(imm8),
        .decoded_nzp(decoded_nzp),
        .reg_write_enable(reg_we),
        .mem_read_enable(mem_re),
        .mem_write_enable(mem_we),
        .nzp_write_enable(nzp_we),
        .decoded_ret(decoded_ret),
        .alu_control(alu_control),
        .reg_input_mux(reg_input_mux),
        .alu_output_mux(alu_out_mux),
        .next_pc_mux(next_pc_mux)
    );

    // ========== Thread Instances ==========
    genvar i;
    generate
        for (i = 0; i < NUM_THREADS; i = i + 1) begin : thread

            wire [7:0] write_back_data = (reg_input_mux == 2'b00) ? alu_out[i] :
                                         (reg_input_mux == 2'b01) ? lsu_out[i] :
                                         imm8;

            // Register File
            RegisterFile RF (
                .clk(clk), .reset(reset), .enable(1'b1),
                .core_state(core_state),
                .rd_addr(rd_addr), .rs_addr(rs_addr), .rt_addr(rt_addr),
                .data_in(write_back_data),
                .reg_input_mux(reg_input_mux),
                .reg_write_enable(reg_we),
                .block_id(block_id),
                .thread_id(thread_id[i]),
                .threads_per_block(threads_per_block),
                .rs_data(rs[i]), .rt_data(rt[i])
            );

            // ALU
            alu ALU (
                .clk(clk), .reset(reset), .enable(1'b1),
                .core_state(core_state),
                .decoded_alu_arithmetic_mux(alu_control),
                .decoded_alu_output_mux(alu_out_mux),
                .rs(rs[i]), .rt(rt[i]),
                .alu_out(alu_out[i])
            );

            // PC_NZP
            PC_NZP PCNZP (
                .clk(clk), .reset(reset), .enable(1'b1),
                .core_state(core_state),
                .current_pc(pc[i]),
                .alu_out(alu_out[i]),
                .imm8(imm8),
                .decoded_nzp(decoded_nzp),
                .nzp_write_enable(nzp_we),
                .next_pc_mux(next_pc_mux),
                .next_pc(current_pc[i]),
                .nzp_flags(nzp[i])
            );

            // LSU
            LSU LSU_inst (
                .clk(clk), .reset(reset), .enable(1'b1),
                .core_state(core_state),
                .decoded_mem_read_enable(mem_re),
                .decoded_mem_write_enable(mem_we),
                .rs(rs[i]), .rt(rt[i]),
                .mem_read_ready(lsu_ready[i]),
                .mem_write_ready(lsu_ready[i]),
                .mem_read_data(lsu_read_data[i]),
                .lsu_out(lsu_out[i]),
                .lsu_state(lsu_state[i]),
                .mem_read_valid(lsu_read_valid[i]),
                .mem_write_valid(lsu_write_valid[i]),
                .mem_read_address(lsu_read_addr[i]),
                .mem_write_address(lsu_write_addr[i]),
                .mem_write_data(lsu_write_data[i])
            );

        end
    endgenerate

endmodule
