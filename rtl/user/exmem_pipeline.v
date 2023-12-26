// exmem_pipeline
//    A Memory system in user project area, with the following specificaiton
// Interface timing:  10T latency for read/write access
//          1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17
// wb_clk_i    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// stb    _/---\___/-------\___/-------\_______
// we     _/---\_______/---\___________________
// addr   __a1_____a2__a3_______a4_a5
// dat_i  __d1_________d2_______
// ack(10T)____________________________________/--\____/-------\___/-------\____
// bram_dat_o   _________________________________________________d3______d4_d5_______
// 

`default_nettype wire

module exmem_pipeline #(
    parameter N = 10
)(
    // Wishbone Slave ports (WB MI A)
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wb_valid,   // request valid
    input  wire        wbs_we_i,   // 1: write, 0: read
    input  wire [3:0]  wbs_sel_i,  // byte-enable
    input  wire [31:0] wbs_dat_i,  // data in
    input  wire [31:0] wbs_adr_i,  // address in
    output reg         wbs_ack_o,  // ready
    output reg  [31:0] wbs_dat_o   // data out
);

    `define SEL_POS 3:0
    `define DAT_POS 35:4
    `define ADR_POS 67:36

    // FIFO for shifting WB request
    reg   [67:0] req_fifo[N-1:0];
    reg  [N-1:0] we_fifo;
    reg  [N-1:0] valid_fifo;

    // Wishbone INPUT request
    wire  [67:0] req_in;

    // BRAM byte enable
    wire   [3:0] byte_en;

    // ------------ prefetch controller ------------
    localparam BURST = 8;
    localparam CBW   = $clog2(BURST + 1);
    reg  [63:0] prefetch_buf[BURST-1:0];  // {address, data}
    reg         prefetch_hit;
    reg  [63:0] decode_block;

    // FIFO input/output control
    reg         fin_stb_r, fin_stb_w;
    reg         fin_we_r, fin_we_w;
    reg   [3:0] fin_sel_r, fin_sel_w;
    reg  [31:0] fin_dat_i_r, fin_dat_i_w;
    reg  [31:0] fin_addr_r, fin_addr_w;
    reg         fout_ack;
    reg  [31:0] fout_addr;
    wire [31:0] bram_dat_o;
    wire [31:0] addr;

    // FSM
    localparam S_IDLE = 0;
    localparam S_WREQ = 1;  // write request
    localparam S_PREF = 2;  // read prefetch
    localparam S_WAIT = 3;  // wait for the second wbs_adr_i in the burst sequence

    reg      [1:0] state_r, state_w;
    reg  [CBW-1:0] cnt_r, cnt_w;
    always @(*) begin
        if (state_r == S_PREF) begin
            cnt_w = (cnt_r < BURST) ? (cnt_r + 1) : cnt_r;
        end
        else begin
            cnt_w = 0;
        end
    end
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            cnt_r <= 0;
        end
        else begin
            cnt_r <= cnt_w;
        end
    end

    always @(*) begin
        state_w     = state_r;
        fin_stb_w   = fin_stb_r;
        fin_we_w    = fin_we_r;
        fin_sel_w   = fin_sel_r;
        fin_dat_i_w = fin_dat_i_r;
        fin_addr_w  = fin_addr_r;

        case (state_r)
            S_WREQ: begin
                state_w   = (fout_ack == 1) ? S_IDLE : state_r;
                fin_stb_w = 0;
            end
            S_PREF: begin
                state_w    = (fout_ack == 1) ? S_WAIT : state_r;
                fin_stb_w  = (cnt_r < (BURST - 1)) ? 1 : 0;
                fin_we_w   = 0;
                fin_addr_w = fin_addr_r + 4;
            end
            S_WAIT: begin
                state_w = S_IDLE;
            end
            default: begin  // S_IDLE
                if (wb_valid && wbs_we_i) begin
                    state_w     = S_WREQ;
                    fin_stb_w   = 1;
                    fin_we_w    = wbs_we_i;
                    fin_sel_w   = wbs_sel_i;
                    fin_dat_i_w = wbs_dat_i;
                    fin_addr_w  = wbs_adr_i;
                end
                else if (wb_valid && ~prefetch_hit) begin
                    state_w     = S_PREF;
                    fin_stb_w   = 1;
                    fin_we_w    = wbs_we_i;
                    fin_sel_w   = wbs_sel_i;
                    fin_dat_i_w = wbs_dat_i;
                    fin_addr_w  = wbs_adr_i;
                end
                else begin
                    state_w   = state_r;
                    fin_stb_w = 0;
                end
            end
        endcase
    end

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            state_r     <= 0;
            fin_stb_r   <= 0;
            fin_we_r    <= 0;
            fin_sel_r   <= 0;
            fin_dat_i_r <= 0;
            fin_addr_r  <= 0;
        end
        else begin
            state_r     <= state_w;
            fin_stb_r   <= fin_stb_w;
            fin_we_r    <= fin_we_w;
            fin_sel_r   <= fin_sel_w;
            fin_dat_i_r <= fin_dat_i_w;
            fin_addr_r  <= fin_addr_w;
        end
    end

    // prefetch buffer
    always @(*) begin
        decode_block = prefetch_buf[wbs_adr_i[4:2]];        // (wbs_adr_i >> 2) % 8
        prefetch_hit = (decode_block[63:32] == wbs_adr_i);
    end
    integer j;
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            for (j = 0; j < BURST; j = j + 1) begin
                prefetch_buf[j] <= 0;
            end
        end
        else begin
            for (j = 0; j < BURST; j = j + 1) begin
                if (j == fout_addr[4:2])  // (fout_addr >> 2) % 8
                    prefetch_buf[j] <= (fout_ack == 1) ? {fout_addr, bram_dat_o} : prefetch_buf[j];
                else
                    prefetch_buf[j] <= prefetch_buf[j];
            end
        end
    end

    // Initalize and shift FIFO
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            valid_fifo <= 0;
            we_fifo    <= 0;
        end
        else begin
            valid_fifo <= {fin_stb_r, valid_fifo[N-1:1]};
            we_fifo    <= {fin_we_r, we_fifo[N-1:1]};
        end
    end

    // Put Wishbone input request into FIFO and shift the FIFO
    integer i;
    assign addr = (fin_addr_r - 32'h38000000) >> 2;
    assign req_in = {addr, fin_dat_i_r, fin_sel_r};
    always @(posedge wb_clk_i) begin
        req_fifo[N-1] <= req_in;
        for (i = 0; i <= N-2; i = i + 1) begin         
            req_fifo[i] <= req_fifo[i + 1];
        end
    end

    // ACK signal is generated 1T after valid_fifo[0] = 1,
    // because BRAM read access takes 1T module bram
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            fout_ack  <= 0;
            fout_addr <= 0;
        end
        else begin
            fout_ack  <= valid_fifo[0];
            fout_addr <= ((req_fifo[0][`ADR_POS] << 2) + 32'h38000000);  // restore to global address
        end
    end

    assign byte_en = req_fifo[0][`SEL_POS] & {4{we_fifo[0]}};

    // WB output control
    always @(*) begin
        if (state_r == S_PREF) begin  // respond for the first request
            wbs_ack_o = fout_ack;
            wbs_dat_o = bram_dat_o;
        end
        else begin
            if (wb_valid && (~wbs_we_i) && prefetch_hit) begin
                wbs_ack_o = 1;
                wbs_dat_o = decode_block[31:0];
            end
            else if (wb_valid && wbs_we_i) begin
                wbs_ack_o = valid_fifo[0];  // send reponse 1 cycle early
                wbs_dat_o = bram_dat_o;
            end
            else begin
                wbs_ack_o = 0;
                wbs_dat_o = 0;
            end
        end
    end
    
    bram user_bram (
        .CLK (wb_clk_i ),
        .WE0 (byte_en  ),
        .EN0 (valid_fifo[0] ),
        .Di0 (req_fifo[0][`DAT_POS] ),
        .Do0 (bram_dat_o ),
        .A0  (req_fifo[0][`ADR_POS] )
    );

endmodule

`default_nettype wire
