module WB_Decode(
    // Wishbone Slave ports
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wbs_stb_i,
    input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,
    
    input wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    
    output wire [2:0] irq
);

wire uart_ack_o, bram_ack_o, mm_ack_o, qsort_ack_o, fir_ack_o;
wire [31:0] uart_dat_o, bram_dat_o, mm_dat_o, qsort_dat_o, fir_dat_o;
reg [31:0] wbs_dat_o_w;
reg wbs_ack_o_w;

// decode 
reg [4:0] decode; 
/*
 * 5'b00000 = invalid
 * 5'b00001 = exmem
 * 5'b00010 = uart
 * 5'b00100 = matmul
 * 5'b01000 = qsort
 * 5'b10000 = fir
*/

always@(*)begin
    if(wbs_cyc_i && wbs_stb_i)begin
        case(wbs_adr_i[31:24])
            8'h30:begin// user ip
                case(wbs_adr_i[11:8])
                    4'h0:decode = 5'b00010;// uart
                    4'h1:decode = 5'b00100;// matmul
                    4'h2:decode = 5'b01000;// qsort
                    4'h3:decode = 5'b10000;// fir
                    default:decode = 5'b00000;
                endcase
            end
            8'h38:begin// user memory
                decode = 5'b00001;
            end
            default:decode = 5'b00000;
        endcase
    end else begin
        decode = 5'b00000;
    end
end

assign wbs_ack_o = uart_ack_o | bram_ack_o | fir_ack_o | qsort_ack_o | mm_ack_o;//uart_ack_o | bram_ack_o | mm_ack_o | qsort_ack_o | fir_ack_o;
assign wbs_dat_o = wbs_dat_o_w;

always@(*)begin
    case(decode)
        5'b00001:wbs_dat_o_w = bram_dat_o;
        5'b00010:wbs_dat_o_w = uart_dat_o;
        5'b00100:wbs_dat_o_w = mm_dat_o;//mm_dat_o;
        5'b01000:wbs_dat_o_w = qsort_dat_o;//qsort_dat_o
        5'b10000:wbs_dat_o_w = fir_dat_o;
        default:wbs_dat_o_w  = 32'd0;
    endcase
end

exmem exmem(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wb_valid       (decode[0]  ),              
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (bram_ack_o ),              
    .wbs_dat_o      (bram_dat_o ),
    .la_data_in      (la_data_in),
    .la_data_out    (la_data_out),
    .la_oenb            (la_oenb),
    .io_in                (io_in),
    .io_out              (io_out),
    .io_oeb              (io_oeb)
);

uart uart_ip(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wb_valid       (decode[1]  ),              
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (uart_ack_o ),              
    .wbs_dat_o      (uart_dat_o ),
    .io_in          (io_in      ),
    .io_out         (io_out     ),
    .io_oeb         (io_oeb     ),
    .user_irq       (irq        )
);

mm_wrapper mm_ip(
    .wb_clk_i         (wb_clk_i  ),
    .wb_rst_i         (wb_rst_i  ),
    .wb_valid         (decode[2] ),
    .wbs_we_i         (wbs_we_i  ),
    .wbs_sel_i        (wbs_sel_i ),
    .wbs_dat_i        (wbs_dat_i ),
    .wbs_adr_i        (wbs_adr_i ),
    .wbs_ack_o        (mm_ack_o ),
    .wbs_dat_o        (mm_dat_o )
);

qsort_wrapper qsort_ip(
    .wb_clk_i         (wb_clk_i  ),
    .wb_rst_i         (wb_rst_i  ),
    .wb_valid         (decode[3] ),
    .wbs_we_i         (wbs_we_i  ),
    .wbs_sel_i        (wbs_sel_i ),
    .wbs_dat_i        (wbs_dat_i ),
    .wbs_adr_i        (wbs_adr_i ),
    .wbs_ack_o        (qsort_ack_o ),
    .wbs_dat_o        (qsort_dat_o )
);

fir_wrapper fir_ip(
    .wb_clk_i         (wb_clk_i  ),
    .wb_rst_i         (wb_rst_i  ),
    .wb_valid         (decode[4] ),
    .wbs_we_i         (wbs_we_i  ),
    .wbs_sel_i        (wbs_sel_i ),
    .wbs_dat_i        (wbs_dat_i ),
    .wbs_adr_i        (wbs_adr_i ),
    .wbs_ack_o        (fir_ack_o ),
    .wbs_dat_o        (fir_dat_o )
);
endmodule
