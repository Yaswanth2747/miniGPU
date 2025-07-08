module tb_register_file;
    reg clk = 0, reset = 0, enable = 1;
    reg [2:0] core_state = 3'b011;
    reg [3:0] rd_addr = 4'd1, rs_addr = 4'd2, rt_addr = 4'd3;
    reg [7:0] data_in = 8'hDE;
    reg [1:0] reg_input_mux = 2'b00;
    reg reg_write_enable = 1;
    reg [7:0] block_id = 8'd1, thread_id = 8'd2, threads_per_block = 8'd4;
    wire [7:0] rs_data, rt_data;

    RegisterFile uut (
        .clk(clk), .reset(reset), .enable(enable),
        .core_state(core_state), .rd_addr(rd_addr),
        .rs_addr(rs_addr), .rt_addr(rt_addr),
        .data_in(data_in), .reg_input_mux(reg_input_mux),
        .reg_write_enable(reg_write_enable),
        .block_id(block_id), .thread_id(thread_id), .threads_per_block(threads_per_block),
        .rs_data(rs_data), .rt_data(rt_data)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #10; reset = 0;
        #10;
        reg_write_enable = 1;
        #10;
        $display("RS: %h, RT: %h", rs_data, rt_data);
        $finish;
    end
endmodule