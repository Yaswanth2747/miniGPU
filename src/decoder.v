module Decoder (
    input clk, reset,
    input [2:0] core_state, // From scheduler ('010'=DECODE)
    input [15:0] instruction,
    output reg [3:0] rd_addr, rs_addr, rt_addr,
    output reg [7:0] imm8,
    output reg [2:0] decoded_nzp,
    output reg reg_write_enable, mem_read_enable, mem_write_enable, nzp_write_enable, decoded_ret,
    output reg [1:0] alu_control, reg_input_mux,
    output reg alu_output_mux, next_pc_mux
);
    // Instruction fields
    wire [3:0] opcode = instruction[15:12];
    wire [3:0] rd = instruction[11:8];
    wire [3:0] rs = instruction[7:4];
    wire [3:0] rt = instruction[3:0];
    wire [2:0] nzp = instruction[10:8];
    wire [7:0] imm = instruction[7:0];
    
    always @(posedge clk) begin
        if (reset) begin
            rd_addr <= 4'b0;
            rs_addr <= 4'b0;
            rt_addr <= 4'b0;
            imm8 <= 8'b0;
            decoded_nzp <= 3'b0;
            reg_write_enable <= 1'b0;
            mem_read_enable <= 1'b0;
            mem_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            alu_control <= 2'b0;
            alu_output_mux <= 1'b0;
            reg_input_mux <= 2'b0;
            next_pc_mux <= 1'b0;
            decoded_ret <= 1'b0;
        end else if (core_state == 3'b010) begin // DECODE state
            // rst ctrl signals
            reg_write_enable <= 1'b0;
            mem_read_enable <= 1'b0;
            mem_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            alu_control <= 2'b0;
            alu_output_mux <= 1'b0;
            reg_input_mux <= 2'b0;
            next_pc_mux <= 1'b0;
            decoded_ret <= 1'b0;
            
            //Extracting fields
            rd_addr <= rd;
            rs_addr <= rs;
            rt_addr <= rt;
            imm8 <= imm;
            decoded_nzp <= nzp;
            
            //Decoding based on opcode
            case (opcode)
                4'b0000: ; // NOP: No control signals
                4'b0001: begin // BRnzp
                    decoded_nzp <= nzp;
                    imm8 <= imm;
                    next_pc_mux <= 1'b1;
                end
                4'b0010: begin // CMP
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_output_mux <= 1'b1;
                    nzp_write_enable <= 1'b1;
                end
                4'b0011: begin // ADD
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b00;
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00; // ALU output
                end
                4'b0100: begin // SUB
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b01;
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00; // ALU output
                end
                4'b0101: begin // MUL
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b10;
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00; // ALU output
                end
                4'b0110: begin // DIV
                    rd_addr <= rd;
                    rs_addr <= rs;
                    rt_addr <= rt;
                    alu_control <= 2'b11;
                    alu_output_mux <= 1'b0;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b00; // ALU output
                end
                4'b0111: begin // LDR
                    rd_addr <= rd;
                    rs_addr <= rs;
                    mem_read_enable <= 1'b1;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b01; // LSU output
                end
                4'b1000: begin // STR
                    rs_addr <= rs;
                    rt_addr <= rt;
                    mem_write_enable <= 1'b1;
                end
                4'b1001: begin // CONST
                    rd_addr <= rd;
                    imm8 <= imm;
                    reg_write_enable <= 1'b1;
                    reg_input_mux <= 2'b10; // Immediate
                end
                4'b1111: begin // RET
                    decoded_ret <= 1'b1;
                end
                default: ; // Invalid opcode
            endcase
        end
    end
endmodule
