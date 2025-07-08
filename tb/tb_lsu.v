module tb_lsu;
    reg clk = 0, reset = 0, enable = 1;
    reg [2:0] core_state = 3'b011;
    reg decoded_mem_read_enable = 1, decoded_mem_write_enable = 0;
    reg [7:0] rs = 8'h10, rt = 8'hAA;
    reg mem_read_ready = 1, mem_write_ready = 1;
    reg [7:0] mem_read_data = 8'h55;
    wire [7:0] lsu_out;
    wire [1:0] lsu_state;
    wire mem_read_valid, mem_write_valid;
    wire [7:0] mem_read_address, mem_write_address, mem_write_data;

    LSU uut (
        .clk(clk), .reset(reset), .enable(enable),
        .core_state(core_state),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .rs(rs), .rt(rt),
        .mem_read_ready(mem_read_ready), .mem_write_ready(mem_write_ready),
        .mem_read_data(mem_read_data),
        .lsu_out(lsu_out),
        .lsu_state(lsu_state),
        .mem_read_valid(mem_read_valid), .mem_write_valid(mem_write_valid),
        .mem_read_address(mem_read_address), .mem_write_address(mem_write_address),
        .mem_write_data(mem_write_data)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #10; reset = 0;
        #50;
        $finish;
    end
endmodule