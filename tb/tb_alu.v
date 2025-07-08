module tb_alu;
    reg clk = 0, reset = 0, enable = 1;
    reg [2:0] core_state = 3'b101;
    reg [1:0] decoded_alu_arithmetic_mux;
    reg decoded_alu_output_mux;
    reg [7:0] rs, rt;
    wire [7:0] alu_out;

    alu uut (
        .clk(clk), .reset(reset), .enable(enable),
        .core_state(core_state),
        .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
        .decoded_alu_output_mux(decoded_alu_output_mux),
        .rs(rs), .rt(rt),
        .alu_out(alu_out)
    );

    always #5 clk = ~clk;

    initial begin
        reset = 1; #10; reset = 0;
        rs = 8'd10; rt = 8'd5;

        decoded_alu_arithmetic_mux = 2'b00; decoded_alu_output_mux = 0; // ADD
        #10;
        decoded_alu_arithmetic_mux = 2'b01; // SUB
        #10;
        decoded_alu_arithmetic_mux = 2'b10; // MUL
        #10;
        decoded_alu_arithmetic_mux = 2'b11; // DIV
        #10;
        $finish;
    end
endmodule