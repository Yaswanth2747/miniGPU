module LSU (
    input clk, reset, enable,
    input [2:0] core_state,                      // from scheduler (011=REQUEST, 110=UPDATE)
    input decoded_mem_read_enable,               // from decoder (1 for LDR)
    input decoded_mem_write_enable,              // from decoder (1 for STR)
    input [7:0] rs, rt,                          // from Register File (address, data)
    input mem_read_ready, mem_write_ready,       // from Memory Controller
    input [7:0] mem_read_data,                   // from Memory Controller
    output reg [7:0] lsu_out,                    // to Register File (LDR result)
    output reg [1:0] lsu_state,                  // to scheduler
    output reg mem_read_valid, mem_write_valid,  // to Memory Controller
    output reg [7:0] mem_read_address, mem_write_address, // to Memory Controller
    output reg [7:0] mem_write_data                       // to Memory Controller
);
    // FSM states
    localparam IDLE = 2'b00, REQUESTING = 2'b01, WAITING = 2'b10, DONE = 2'b11;
    
    always @(posedge clk) begin
        if (reset) begin
            lsu_state <= IDLE;
            lsu_out <= 8'b0;
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;
            mem_read_address <= 8'b0;
            mem_write_address <= 8'b0;
            mem_write_data <= 8'b0;
        end else if (enable && (decoded_mem_read_enable || decoded_mem_write_enable)) begin
            case (lsu_state)
                IDLE: begin
                    if (core_state == 3'b011) begin // REQUEST state
                        lsu_state <= REQUESTING;
                        if (decoded_mem_read_enable) begin
                            mem_read_valid <= 1'b1;
                            mem_read_address <= rs;
                        end else if (decoded_mem_write_enable) begin
                            mem_write_valid <= 1'b1;
                            mem_write_address <= rs;
                            mem_write_data <= rt;
                        end
                    end
                end
                REQUESTING: begin
                    if (mem_read_ready && decoded_mem_read_enable) begin
                        lsu_out <= mem_read_data;
                        mem_read_valid <= 1'b0;
                        lsu_state <= WAITING;
                    end else if (mem_write_ready && decoded_mem_write_enable) begin
                        mem_write_valid <= 1'b0;
                        lsu_state <= WAITING;
                    end
                end
                WAITING: begin
                    if (core_state == 3'b110) begin // UPDATE state
                        lsu_state <= DONE;
                    end
                end
                DONE: begin
                    if (core_state != 3'b110) begin
                        lsu_state <= IDLE;
                    end
                end
            endcase
        end else begin
            lsu_state <= IDLE;
            mem_read_valid <= 1'b0;
            mem_write_valid <= 1'b0;
        end
    end
endmodule
