module tb_decoder;
    reg clk = 0, reset = 0;
    reg [2:0] core_state = 3'b010;
    reg [15:0] instruction = 16'b0011_0001_0010_0011; // ADD R1, R2, R3
    wire [3:0] rd_addr, rs_addr, rt_addr;
    wire [7:0] imm8;
    wire [2:0] decoded_nzp;
    wire reg_write_enable, mem_read_enable, mem_write_enable, nzp_write_enable, decoded_ret;
    wire [1:0] alu_control, reg_input_mux;
    wire alu_output_mux, next_pc_mux;

    Decoder uut (
        .clk(clk), .reset(reset), .core_state(core_state),
        .instruction(instruction), .rd_addr(rd_addr),
        .rs_addr(rs_addr), .rt_addr(rt_addr), .imm8(imm8),
        .decoded_nzp(decoded_nzp), .reg_write_enable(reg_write_enable),
        .mem_read_enable(mem_read_enable), .mem_write_enable(mem_write_enable),
        .nzp_write_enable(nzp_write_enable), .decoded_ret(decoded_ret),
        .alu_control(alu_control), .reg_input_mux(reg_input_mux),
        .alu_output_mux(alu_output_mux), .next_pc_mux(next_pc_mux)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #10; reset = 0;
        #10;
        $display("RD: %d, RS: %d, RT: %d, IMM: %d", rd_addr, rs_addr, rt_addr, imm8);
        $finish;
    end
endmodule
