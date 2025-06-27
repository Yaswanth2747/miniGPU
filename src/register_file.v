module RegisterFile (
    input clk, reset, enable,
    input [2:0] core_state,                                   // From scheduler (011 = REQUEST)
    input [3:0] rd_addr, rs_addr, rt_addr,                   // 4-bit register addresses
    input [7:0] data_in,                                    // write data (from ALU, LSU, or immediate)
    input [1:0] reg_input_mux,                             // selects data source (00=ALU, 01=LSU, 10=Immediate)
    input reg_write_enable,                               // Enables write to Rd
    input [7:0] block_id, thread_id, threads_per_block,  // Constants
    output [7:0] rs_data, rt_data                       // Read data
);
    // Register array: 16 registers, 8 bits each
    reg [7:0] registers [0:15];
    
    // Read logic, it should be noted that this is `combinational`
    assign rs_data = registers[rs_addr];
    assign rt_data = registers[rt_addr];
    
    // Write logic
    always @(posedge clk) begin
        if (reset) begin
            // rst all registers to 0
            integer i;
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 8'b0;
            // Initialisisng reserved registers (R13=block_id, R14=thread_id, R15=threads_per_block)
            registers[13] <= block_id;
            registers[14] <= thread_id;
            registers[15] <= threads_per_block;
        end else if (enable && core_state == 3'b011 && reg_write_enable) begin
            // Writing data to Rd based on reg_input_mux
            case (reg_input_mux)
                2'b00, 2'b01, 2'b10: // ALU, LSU, or Immediate
                  if (rd_addr != 13 && rd_addr != 14 && rd_addr != 15) // Protecting reserved registers 13,14,15 from being overwritten.
                        registers[rd_addr] <= data_in;
                default: ; // Not req
            endcase
        end
    end
endmodule
