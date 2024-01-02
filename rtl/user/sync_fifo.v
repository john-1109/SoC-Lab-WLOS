/********************************************************************
* Filename: sync_fifo.v
* Description:
*     Synchronous FIFO
* Parameters:
*     - DATA_WIDTH: FIFO data width
*     - FIFO_DEPTH: FIFO depth
*     - FULL_THRES: full threshold for iready
* Note:
*     - FULL_THRES must be less than FIFO_DEPTH.
*********************************************************************/

module sync_fifo # (
    parameter DATA_WIDTH = 8,
    parameter FULL_THRES = 3,
    parameter FIFO_DEPTH = (FULL_THRES + 3)
)
(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ivalid,
    output wire                  iready,
    input  wire [DATA_WIDTH-1:0] idata,
    output wire                  ovalid,
    input  wire                  oready,
    output wire [DATA_WIDTH-1:0] odata,
    output wire                  empty
);

    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);
    integer i;

    reg [PTR_WIDTH-1:0] iptr_r, iptr_w;
    reg [PTR_WIDTH-1:0] optr_r, optr_w;
    reg [  PTR_WIDTH:0] size_r, size_w;
    assign empty = (size_r == 0);

    reg [DATA_WIDTH-1:0] mem_r[FIFO_DEPTH-1:0], mem_w[FIFO_DEPTH-1:0];

    reg [DATA_WIDTH-1:0] odata_r, odata_w;
    assign odata = odata_r;

    reg iready_r, iready_w;
    reg ovalid_r, ovalid_w;
    assign iready = iready_r;
    assign ovalid = ovalid_r;

    always @(*) begin
        iptr_w   = (ivalid) ? ((iptr_r == (FIFO_DEPTH - 1)) ? 0 : iptr_r + 1) : iptr_r;
        optr_w   = (ovalid & oready) ? ((optr_r == (FIFO_DEPTH - 1)) ? 0 : optr_r + 1) : optr_r;
        size_w   = (iptr_w >= optr_w) ? (iptr_w - optr_w) : (FIFO_DEPTH - optr_w + iptr_w);
        iready_w = (size_w < FULL_THRES);
        ovalid_w = (size_r != 0) && !((size_r == 1) && (ovalid && oready));
        odata_w  = mem_r[optr_w];
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            iptr_r   <= 0;
            optr_r   <= 0;
            size_r   <= 0;
            iready_r <= 0;
            ovalid_r <= 0;
            odata_r  <= 0;
        end
        else begin
            iptr_r   <= iptr_w;
            optr_r   <= optr_w;
            size_r   <= size_w;
            iready_r <= iready_w;
            ovalid_r <= ovalid_w;
            odata_r  <= odata_w;
        end
    end

    always @(*) begin
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            mem_w[i] = mem_r[i];
        end
        if (ivalid) begin
            mem_w[iptr_r] = idata;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                mem_r[i] <= 0;
            end
        end
        else begin
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                mem_r[i] <= mem_w[i];
            end
        end
    end
endmodule
