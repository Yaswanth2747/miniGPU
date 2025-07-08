module tb_core;
    parameter NUM_THREADS = 4;
    reg clk = 0, reset = 0, core_start = 1;
    reg [7:0] core_block_id = 8'd0, core_thread_count = 8'd4;
    wire core_done;

    wire [NUM_THREADS-1:0] lsu_read_valid, lsu_write_valid;
    wire [NUM_THREADS-1:0][7:0] lsu_read_addr, lsu_write_addr, lsu_write_data;
    wire [NUM_THREADS-1:0] lsu_ready;
    wire [NUM_THREADS-1:0][7:0] lsu_read_data;

    core #(.NUM_THREADS(NUM_THREADS)) uut (
        .clk(clk), .reset(reset), .core_start(core_start),
        .core_block_id(core_block_id), .core_thread_count(core_thread_count),
        .core_done(core_done),
        .lsu_read_valid(lsu_read_valid), .lsu_write_valid(lsu_write_valid),
        .lsu_read_addr(lsu_read_addr), .lsu_write_addr(lsu_write_addr),
        .lsu_write_data(lsu_write_data), .lsu_ready(lsu_ready),
        .lsu_read_data(lsu_read_data)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #20; reset = 0;
        core_start = 1; #10;
        core_start = 0; #100;
        $finish;
    end
endmodule
