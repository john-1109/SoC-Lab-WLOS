module mm 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32
)
(

    //write ap_start
    output  wire                     awready, // coefficients address ready to accept from tb
    output  wire                      wready,  // coefficients ready to accept from tb
    input   wire                     awvalid, // coefficients address valid
    input   wire [(pADDR_WIDTH-1):0] awaddr,  // coefficients address
    input   wire                     wvalid, // coefficients valid
    input   wire [(pDATA_WIDTH-1):0] wdata,  //coefficients comes from here

    //check ap_done/ap_idle
    output  reg                     arready, // data address ready to accept from tb
    input   wire                     rready, // tb is ready to accept data
    input   wire                     arvalid, // read address from tb is valid
    input   wire [(pADDR_WIDTH-1):0] araddr, // read address from tb
    output  reg                      rvalid, // data to tb valid
    output  reg  [(pDATA_WIDTH-1):0] rdata,  // data to tb

    input   wire                     ss_tvalid, //data stream in valid
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, //data stream in
    input   wire                     ss_tlast, //data stream in last
    output                        ss_tready, //ready to accept data stream in

    input   wire                     sm_tready, //tb ready to accept data stream out
    output  reg                      sm_tvalid, //data stream out valid
    output  reg  [(pDATA_WIDTH-1):0] sm_tdata, //data stream out
    output  reg                      sm_tlast, //data stream out last


    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

// regs and wires declaration
reg ap_done_w, ap_done_r;
reg ap_idle_w, ap_idle_r;
reg ap_start_w, ap_start_r;
reg [3:0] state_w, state_r;
reg [31:0] a_rowused_w [0:3], a_rowused_r [0:3];
reg [31:0] a_rowload_w [0:2], a_rowload_r [0:2];
reg [31:0] b_w [0:15], b_r [0:15];
reg [31:0] b_used [0:3];
reg [5:0] stream_cnt_w, stream_cnt_r;
reg [5:0] out_cnt_w, out_cnt_r;
reg [31:0] out_w [0:15], out_r [0:15];
reg out_valid_w [0:15], out_valid_r[0:15];
wire [31:0] mul_out;
reg comp_valid_w, comp_valid_r;


wire [pDATA_WIDTH-1:0] ap_data;

integer i,j,k,m;
// assignments
assign ap_data = {29'b0 ,ap_idle_r, ap_done_r, ap_start_r};
assign ss_tready = 1;
assign awready = 1;
assign wready = 1;

// states
localparam S_IDLE = 0;
localparam S_COMPUTE = 1;


RowMulCol rowmulcol0(
    .a0(a_rowused_r[0]),
    .a1(a_rowused_r[1]),
    .a2(a_rowused_r[2]),
    .a3(a_rowused_r[3]),
    .b0(b_used[0]),
    .b1(b_used[1]),
    .b2(b_used[2]),
    .b3(b_used[3]),
    .clk(axis_clk),
    .out(mul_out)
);

// combinational logic

// state machine

always @(*) begin
    state_w = state_r;

    case (state_r)
        S_IDLE: begin
            if (ap_start_r) begin
                state_w = S_COMPUTE;
            end
        end
        S_COMPUTE: begin

        end
    endcase
end

//
always @(*) begin
    ap_idle_w = ap_idle_r;
    ap_done_w = ap_done_r;
    for (i = 0; i<4; i = i + 1) begin
        b_used[i] = b_r[i*4+stream_cnt_r[1:0]];
    end
    case (state_r)
        S_IDLE: begin
            if (ap_start_r) begin
                ap_idle_w = 0;
            end
        end
        S_COMPUTE: begin
            if (stream_cnt_r >= 36) begin
                ap_done_w = 1;
                ap_idle_w = 1;
            end
        end
    endcase
end

// control signal in
always @(*) begin
    ap_start_w = ap_start_r;
    if (wvalid)begin
        ap_start_w = wdata[0];
    end
end

// control signal out
always @(*) begin
    rvalid = 1;
    arready = 1;
    rdata = ap_data;
end

// data stream in
always @(*) begin
    
    // idk why here need to use a different integer...
    for (k = 0; k<16; k = k + 1) begin
        b_w[k] = b_r[k];
    end
    for (m = 0; m<4; m = m + 1) begin
        a_rowused_w[m] = a_rowused_r[m];
        a_rowload_w[m] = a_rowload_r[m];
    end

    stream_cnt_w = stream_cnt_r;
    comp_valid_w = 0;

    if (ss_tvalid) begin
        stream_cnt_w = stream_cnt_r + 1;
        if (stream_cnt_r < 16) begin //stream in b
            for (i = 0; i<15; i = i + 1) begin
                b_w[i] = b_r[i+1];
            end
            b_w[15] = ss_tdata;
        end

        else begin
            a_rowload_w[2] = ss_tdata;
            a_rowload_w[1] = a_rowload_r[2];
            a_rowload_w[0] = a_rowload_r[1];

            if (stream_cnt_r[1:0] == 3) begin //load a full column
                for (i = 0; i<3; i = i + 1) begin
                    a_rowused_w[i] = a_rowload_r[i];
                end
                a_rowused_w[3] = ss_tdata;
            end
        end

        if (stream_cnt_r >= 20) begin
            comp_valid_w = 1;
        end

    end

    if (stream_cnt_r >= 32) begin // keep counting
        stream_cnt_w = stream_cnt_r + 1;
        comp_valid_w = 1;
    end

    if (stream_cnt_r == 36) begin // stay
        stream_cnt_w = 36;
        comp_valid_w = 0;
    end
end

// data stream out
always @(*) begin

    // idk why here need to use a different integer...
    for (j = 0; j<16; j = j + 1) begin
        out_w[j] = out_r[j];
        out_valid_w[j] = out_valid_r[j];
    end

    if (comp_valid_r) begin
        out_w[stream_cnt_r - 21] = mul_out;
        out_valid_w[stream_cnt_r - 21] = 1;
    end

    sm_tvalid = 0;
    out_cnt_w = out_cnt_r;

    sm_tdata = out_r[out_cnt_r];

    if (out_valid_r[out_cnt_r]) begin
        sm_tvalid = 1;
    end

    if (sm_tready && sm_tvalid) begin
        out_cnt_w = out_cnt_r + 1;
    end
end

// sequential logic
always @(posedge axis_clk or negedge axis_rst_n) begin
    if (~axis_rst_n) begin
        ap_done_r <= 0;
        ap_idle_r <= 1;
        ap_start_r <= 0;
        state_r <= S_IDLE;
        stream_cnt_r <= 0;
        out_cnt_r <= 0;
        comp_valid_r <= 0;
        for (i = 0; i < 16; i = i + 1) begin
            out_valid_r[i] <= 0;
        end
        for (i = 0; i < 4; i = i + 1) begin
            a_rowused_r[i] <= 0;
            a_rowload_r[i] <= 0;
        end
        for (i = 0; i < 16; i = i + 1) begin
            b_r[i] <= 0;
        end
        for (i = 0; i < 16; i = i + 1) begin
            out_r[i] <= 0;
        end
    end
    else begin
        ap_done_r <= ap_done_w;
        ap_idle_r <= ap_idle_w;
        ap_start_r <= ap_start_w;
        state_r <= state_w;
        stream_cnt_r <= stream_cnt_w;
        out_cnt_r <= out_cnt_w;
        comp_valid_r <= comp_valid_w;
        for (i = 0; i < 16; i = i + 1) begin
            out_valid_r[i] <= out_valid_w[i];
        end
        for (i = 0; i < 4; i = i + 1) begin
            a_rowused_r[i] <= a_rowused_w[i];
            a_rowload_r[i] <= a_rowload_w[i];
        end
        for (i = 0; i < 16; i = i + 1) begin
            b_r[i] <= b_w[i];
        end
        for (i = 0; i < 16; i = i + 1) begin
            out_r[i] <= out_w[i];
        end
    end
end


endmodule


module RowMulCol(
    input [31:0] a0,
    input [31:0] a1,
    input [31:0] a2,
    input [31:0] a3,
    input [31:0] b0,
    input [31:0] b1,
    input [31:0] b2,
    input [31:0] b3,
    input clk,
    output reg [31:0] out
);

reg [31:0] a0b0_r, a1b1_r, a2b2_r, a3b3_r;
reg [31:0] a0b0_w, a1b1_w, a2b2_w, a3b3_w;


always @(*) begin
    a0b0_w = a0 * b0;
    a1b1_w = a1 * b1;
    a2b2_w = a2 * b2;
    a3b3_w = a3 * b3;
    out = a0b0_r + a1b1_r + a2b2_r + a3b3_r;
end

always @(posedge clk) begin
    a0b0_r <= a0b0_w;
    a1b1_r <= a1b1_w;
    a2b2_r <= a2b2_w;
    a3b3_r <= a3b3_w;
end

endmodule
