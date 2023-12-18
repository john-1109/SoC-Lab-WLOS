`timescale 1ns / 1ps
//`define MPRJ_IO_PADS 32
module mm_wrapper (  
    input           wb_clk_i,
    input           wb_rst_i,
    input           wb_valid,
    input           wbs_we_i,
    input   [3:0]   wbs_sel_i,
    input  [31:0]   wbs_dat_i,
    input  [31:0]   wbs_adr_i,
    output reg          wbs_ack_o,
    output reg [31:0]   wbs_dat_o

);
 

localparam slave_id = 4'h1;

// axi_lite write
wire awready, wready;
reg awvalid, wvalid, awvalid_w, wvalid_w;
reg [11:0] awaddr,   awaddr_w;
reg [31:0] wdata,   wdata_w;



// axi_lite read
reg  rready, arvalid , rready_w, arvalid_w;
wire  arready, rvalid;
reg  [11:0] araddr,araddr_w;
wire [31:0] rdata;


// axi_s slave (write)
wire  ss_tready;
reg ss_tvalid ,ss_tvalid_w;
reg [31:0] ss_tdata, ss_tdata_w;


// axi_s master (read)
reg sm_tready,sm_tready_w;
wire        sm_tvalid;
wire [31:0] sm_tdata;


// ctrl
wire axil_valid,axis_valid;
wire read; // 1: read, 0: write

wire wb_valid;

reg wbs_ack_o_w;
reg [31:0] wbs_dat_o_w;

assign axil_valid = (wbs_adr_i[31:24] == 8'h30) && (wbs_adr_i[7:4] < 4'h8) && (wbs_adr_i[11:8] == slave_id);
assign axis_valid = (wbs_adr_i[31:24] == 8'h30) && (wbs_adr_i[7:4] == 4'h8) && (wbs_adr_i[11:8] == slave_id);




// mm_module
mm inst_mm(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(),

        .axis_clk(wb_clk_i),
        .axis_rst_n(~wb_rst_i)
);

reg [2:0] wb_state_w, wb_state_r;
reg [31:0] axilr_data_w, axilr_data_r;
reg [31:0] sm_data_buf_w, sm_data_buf_r;
localparam S_IDLE = 0;
localparam S_ACK = 1;
localparam S_AXILW = 2;
localparam S_AXILR_WAITREADY = 3;
localparam S_AXILR = 4;
localparam S_AXISW = 5;
localparam S_AXISR = 6;


always @(*) begin
    awvalid_w = 0;
    wvalid_w = 0;
    awaddr_w = awaddr;
    wdata_w = wdata;

    arvalid_w = 0;
    rready_w = 0;
    araddr_w = araddr;
    axilr_data_w = axilr_data_r;

    ss_tvalid_w = 0;
    ss_tdata_w = ss_tdata;

    sm_tready_w = 0;
    sm_data_buf_w = sm_data_buf_r;

    wb_state_w = wb_state_r;
    wbs_ack_o = 0;
    /*
    case (wb_state_r)
        S_IDLE:begin
            if (wb_valid && (wbs_we_i) && axil_valid) begin
                awvalid_w = 1;
                wvalid_w = 1;
                awaddr_w = wbs_adr_i[11:0] - (slave_id << 8);
                wdata_w = wbs_dat_i[31:0];
                wb_state_w = S_AXILW;
            end

            if (wb_valid && (~wbs_we_i) && axil_valid) begin
                arvalid_w = 1;
                araddr_w = wbs_adr_i[11:0] - (slave_id << 8);
                wb_state_w = S_AXILR_WAITREADY;
            end

            if (wb_valid && (wbs_we_i) && axis_valid) begin
                ss_tvalid_w = 1;
                ss_tdata_w = wbs_dat_i[31:0];
                wb_state_w = S_AXISW;
            end

            if (wb_valid && (~wbs_we_i) && axis_valid) begin
                sm_tready_w = 1;
                wb_state_w = S_AXISR;
            end
        end 
        S_AXILW:begin
            if (awready && wready) begin
                awvalid_w = 0;
                wvalid_w = 0;
                wb_state_w = S_ACK;
            end
        end
        S_AXILR_WAITREADY:begin
            arvalid_w = 1;
            if (arready) begin
                arvalid_w = 0;
                wb_state_w = S_AXILR;
                rready_w = 1;
            end
        end
        S_AXILR:begin
            if (rvalid) begin
                axilr_data_w = rdata;
                wb_state_w = S_ACK;
            end
        end
        S_AXISW:begin
            if (ss_tready) begin
                ss_tvalid_w = 0;
                wb_state_w = S_ACK;
            end
        end
        S_AXISR:begin
            sm_tready_w = 1;
            if (sm_tvalid) begin
                sm_data_buf_w = sm_tdata;
                wb_state_w = S_ACK;
            end
        end
        S_ACK:begin
            wb_state_w = S_IDLE;
            wbs_ack_o = 1;
        end
    endcase
    */
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)begin
        wbs_dat_o <= 0;

        awvalid <= 0;
        wvalid <= 0;
        awaddr <= 0;
        wdata <= 0;

        arvalid <= 0;
        rready <= 0;
        araddr <= 0;

        ss_tvalid <= 0;
        ss_tdata <= 0;

        sm_tready <= 0;
        sm_data_buf_r <= 0;

        wb_state_r <= 0;

    end
    else begin
        wbs_dat_o <= axis_valid ? sm_data_buf_w : axilr_data_w;

        awvalid <= awvalid_w;
        wvalid <= wvalid_w;
        awaddr <= awaddr_w;
        wdata <= wdata_w;

        arvalid <= arvalid_w;
        rready <= rready_w;
        araddr <= araddr_w;

        ss_tvalid <= ss_tvalid_w;
        ss_tdata <= ss_tdata_w;

        sm_tready <= sm_tready_w;

        axilr_data_r <= axilr_data_w;

        sm_data_buf_r <= sm_data_buf_w;

        wb_state_r <= wb_state_w;

    end
end




endmodule
