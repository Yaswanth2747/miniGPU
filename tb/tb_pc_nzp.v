module tb_pc_nzp;
    reg clk = 0, reset = 0, enable = 1;
    reg [2:0] core_state = 3'b101;
    reg [7:0] current_pc = 8'd3, alu_out = 8'b001;
    reg [7:0] imm8 = 8'd9;
    reg [2:0] decoded_nzp = 3'b001;
    reg nzp_write_enable = 1;
    reg next_pc_mux = 1;
    wire [7:0] next_pc;
    wire [2:0] nzp_flags;

    PC_NZP uut (
        .clk(clk), .reset(reset), .enable(enable),
        .core_state(core_state),
        .current_pc(current_pc), .alu_out(alu_out),
        .imm8(imm8), .decoded_nzp(decoded_nzp),
        .nzp_write_enable(nzp_write_enable),
        .next_pc_mux(next_pc_mux),
        .next_pc(next_pc), .nzp_flags(nzp_flags)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #10; reset = 0;
        #30;
        core_state = 3'b110; // update NZP
        #10;
        core_state = 3'b101;
        #10;
        $finish;
    end
endmodule