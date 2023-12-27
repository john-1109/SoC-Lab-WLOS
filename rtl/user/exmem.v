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
    output wire [31:0] wbs_dat_o,
    
    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,
    
    // IOs
    input wire[`MPRJ_IO_PADS-1:0] io_in,
    output wire[`MPRJ_IO_PADS-1:0] io_out,
    output wire[`MPRJ_IO_PADS-1:0] io_oeb
);

    wire clk;
    wire rst, rst_n;
    wire valid;

    wire sdram_cle;
    wire sdram_cs;
    wire sdram_cas;
    wire sdram_ras;
    wire sdram_we;
    wire sdram_dqm;
    wire [1:0] sdram_ba;
    wire [15:0] sdram_a;
    wire burst_out;
    wire [31:0] d2c_data;
    wire [31:0] c2d_data;
    wire [3:0]  bram_mask;

    wire [24:0] ctrl_addr;
    wire ctrl_busy;
    wire ctrl_in_valid, ctrl_out_valid;

    reg ctrl_in_valid_q;
    
    // WB MI A
    
    assign valid = wb_valid;//(wbs_adr_i[31:16]==16'h3800)?wbs_stb_i && wbs_cyc_i:1'b0;
    assign ctrl_in_valid = wbs_we_i ? valid : ~ctrl_in_valid_q && valid;
    assign wbs_ack_o = (wbs_we_i) ? ~ctrl_busy && valid : ctrl_out_valid; 
    assign bram_mask = wbs_sel_i & {4{wbs_we_i}};
    assign ctrl_addr = wbs_adr_i[24:0];

    // IO
    assign io_out = d2c_data;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, d2c_data};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;
    assign rst_n = ~rst;

    always @(posedge clk) begin
        if (rst) begin
            ctrl_in_valid_q <= 1'b0;
        end
        else begin
            if (~wbs_we_i && valid && ~ctrl_busy && ctrl_in_valid_q == 1'b0)
                ctrl_in_valid_q <= 1'b1;
            else if (ctrl_out_valid)
                ctrl_in_valid_q <= 1'b0;
        end
    end

    
    sdram_controller user_sdram_controller (
        .clk(clk),
        .rst(rst),
        
        .sdram_cle(sdram_cle),
        .sdram_cs(sdram_cs),
        .sdram_cas(sdram_cas),
        .sdram_ras(sdram_ras),
        .sdram_we(sdram_we),
        .sdram_dqm(sdram_dqm),
        .sdram_ba(sdram_ba),
        .sdram_a(sdram_a),
        .sdram_dqi(d2c_data),
        .sdram_dqo(c2d_data),

        .user_addr(ctrl_addr),
        .rw(valid&wbs_we_i),
        .data_in(wbs_dat_i),
        .data_out(wbs_dat_o),
        .busy(ctrl_busy),
        .in_valid(ctrl_in_valid),
        .out_valid(ctrl_out_valid)
    );

    sdr user_bram (
        .Rst_n(rst_n),
        .Clk(clk),
        .Cke(sdram_cle),
        .Cs_n(sdram_cs),
        .Ras_n(sdram_ras),
        .Cas_n(sdram_cas),
        .We_n(sdram_we),
        .Addr(sdram_a),
        .Ba(sdram_ba),
        .Dqm(bram_mask),
        .Dqi(c2d_data),
        .Dqo(d2c_data)
    );
    /*
    always@(posedge clk)begin
        if(wbs_ack_o)begin
            if(wbs_we_i)
                $display("Write: addr = %x, data = %x, time = %d", wbs_adr_i, wbs_dat_i, $time);
            else
                $display("Read : addr = %x, data = %x, time = %d",wbs_adr_i, wbs_dat_o, $time);
        end
    end
    */
endmodule

`default_nettype wire
