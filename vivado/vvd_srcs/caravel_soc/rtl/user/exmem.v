`default_nettype wire

module exmem #(
    parameter BITS = 32,
    parameter DELAYS = 10,
    parameter MPRJ_IO_PADS = 38
)(
    // Wishbone Slave ports (WB MI A)
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wb_valid,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o,
    output reg [31:0] wbs_dat_o
);

wire [BITS-1:0] bram_do; 
wire [BITS-1:0] bram_di;
wire [12-1:0] bram_adr;
wire [3:0] bram_we;
wire bram_valid;
    
reg ready;
reg [3:0] delay_cnt;

// WB MI A
assign bram_valid = wb_valid;
assign bram_we = wbs_sel_i & {4{wbs_we_i}};
assign bram_di = wbs_dat_i;
assign bram_adr = (wbs_adr_i - 32'h38000000) >> 2;
assign wbs_ack_o = ready;

always@(posedge wb_clk_i or posedge wb_rst_i)begin
    if(wb_rst_i)begin
        delay_cnt <= 0;
        ready <= 0;
        wbs_dat_o <= 0;
    end else begin
        delay_cnt <= (delay_cnt == DELAYS) ? 0 : (wb_valid == 1 && ready != 1) ? delay_cnt + 1 : delay_cnt;
        ready <= (delay_cnt == DELAYS) ? 1 : 0;
        wbs_dat_o <= (delay_cnt == DELAYS) ? bram_do : 0;
    end
end

bram user_bram (
    .CLK(wb_clk_i),
    .WE0(bram_we),
    .EN0(bram_valid),
    .Di0(bram_di),
    .Do0(bram_do),
    .A0({20'b0, bram_adr})
);

endmodule

`default_nettype wire
