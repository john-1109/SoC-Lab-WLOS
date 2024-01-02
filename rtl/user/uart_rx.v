module uart_receive (
  input wire        rst_n,
  input wire        clk,
  input wire [31:0] clk_div,
  input wire        rx,
  output reg        irq,
  output reg [7:0]  rx_data,
  input wire        rx_finish,
  output reg        frame_err,
  output reg        busy
);

  parameter WAIT        = 4'b0000;
  parameter START_BIT   = 4'b0001;
  parameter GET_DATA    = 4'b0010;
  parameter STOP_BIT    = 4'b0011;
  parameter WAIT_READ   = 4'b0100;
  parameter FRAME_ERR   = 4'b0101;
  parameter IRQ         = 4'b0110;
  parameter STORE_DATA  = 4'b0111;

  reg  [31:0] clk_cnt;

  reg  [3:0] state;
  reg  [2:0] rx_index;
  reg  [7:0] buf_data;

  reg        fifo_ivalid;
  wire       fifo_iready;
  wire       fifo_ifulln;  // FIFO not full
  reg  [7:0] fifo_idata;
  wire       fifo_ovalid;
  reg        fifo_oready;
  wire [7:0] fifo_odata;
  wire       fifo_empty;

  reg  [7:0] fifo_counter;
  wire       timeout_flag;
  localparam TIMEOUT = 5;

  assign timeout_flag = (fifo_counter >= TIMEOUT);
  
  sync_fifo # (
      .DATA_WIDTH (8),
      .FIFO_DEPTH (8),
      .FULL_THRES (6)
  ) rx_fifo_inst (
      .clk    (clk         ),
      .rst_n  (rst_n       ),
      .ivalid (fifo_ivalid ),
      .iready (fifo_iready ),
      .ifulln (fifo_ifulln ),  // FIFO not full
      .idata  (fifo_idata  ),
      .ovalid (fifo_ovalid ),
      .oready (fifo_oready ),
      .odata  (fifo_odata  ),
      .empty  (fifo_empty  )
  );

  always @(*) begin
    fifo_ivalid = 1'b0;
    fifo_idata  = 8'b0;
    fifo_oready = 1'b0;

    case (state)
      STORE_DATA: begin
        // check if FIFO is not full
        if (fifo_ifulln) begin
          fifo_ivalid = 1'b1;
          fifo_idata  = buf_data;
        end
        else begin
          fifo_ivalid = 1'b0;
          fifo_idata  = 8'b0;
        end
      end
      IRQ: begin
        fifo_oready = 1'b1;
      end
      default: begin
        fifo_ivalid = 1'b0;
        fifo_idata  = 8'b0;
        fifo_oready = 1'b0;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      fifo_counter <= 0;
    end
    else begin
      if (state == WAIT) begin
        if (clk_cnt == (clk_div - 1)) begin
          fifo_counter <= fifo_counter + 1;
        end
        else begin
          fifo_counter <= fifo_counter;
        end
      end
      else begin
        fifo_counter <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state     <= WAIT;
      clk_cnt   <= 32'h0000_0000;
      rx_index  <= 3'b000;
      irq       <= 1'b0;
      frame_err <= 1'b0;
      rx_data   <= 8'h0;
      busy      <= 1'b0;
      buf_data  <= 8'h0;
    end
    else begin
      case(state)
        WAIT: begin
          irq <= 1'b0;
          frame_err <= 1'b0;
          busy <= 1'b0;
          rx_data <= 8'b0;
          if (timeout_flag && ~fifo_empty) begin  // timeout
            state <= IRQ;
            clk_cnt <= 32'h0000_0000;
          end
          else if (rx == 1'b0) begin  // Start bit detected
            state <= START_BIT;
            clk_cnt <= 32'h0000_0000;
          end
          else begin
            // clk_cnt used for fifo_counter
            if (clk_cnt == (clk_div - 1)) begin
              clk_cnt <= 32'h0000_0000;
            end
            else begin
              clk_cnt <= clk_cnt + 32'h0000_0001;
            end
          end
          buf_data <= 8'b0;
        end
        START_BIT: begin
          // Check middle of start bit to make sure it's still low
          if(clk_cnt == ((clk_div >> 1) - 1)) begin
            clk_cnt <= 32'h0000_0000;
            if(rx == 1'b0) begin
              state <= GET_DATA;
            end
          end else begin
            clk_cnt <= clk_cnt + 32'h0000_0001;
          end
          busy <= 1'b1;
        end
        GET_DATA: begin
          // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
          if(clk_cnt == (clk_div - 1)) begin
            clk_cnt <= 32'h0000_0000;
            if(rx_index == 3'b111) begin
              state <= STOP_BIT;
            end
            rx_index <= rx_index + 3'b001;
            buf_data[rx_index] <= rx;
            //$display("rx data bit index:%d %b", rx_index, rx_data[rx_index]);
          end else begin
            clk_cnt <= clk_cnt + 32'h0000_0001;
          end
          busy <= 1'b1;
        end
        STOP_BIT: begin
          // Receive Stop bit.  Stop bit = 1
          if(clk_cnt == (clk_div - 1)) begin
            clk_cnt <= 32'h0000_0000;
            if(rx == 1'b1) begin
              state <= STORE_DATA;  // IRQ;
              frame_err <= 1'b0;
            end else begin
              state <= FRAME_ERR;
              frame_err <= 1'b1;
            end
          end else begin
            clk_cnt <= clk_cnt + 32'h0000_0001;
          end
          busy <= 1'b1;
        end
        STORE_DATA: begin
          irq  <= 1'b0;
          busy <= 1'b1;
          // check if FIFO is ready
          state <= (fifo_iready) ? WAIT : IRQ;
        end
        IRQ: begin
          irq     <= 1'b1;
          state   <= WAIT_READ;
          busy    <= 1'b0;
          rx_data <= (fifo_ovalid & fifo_oready) ? fifo_odata : buf_data;
        end
        WAIT_READ: begin
          irq  <= 1'b0;
          busy <= 1'b0;
          if(rx_finish)
            state <= WAIT;
          else
            state <= WAIT_READ;
        end
        FRAME_ERR: begin
            state     <= WAIT;
            irq       <= 0;
            frame_err <= 0;
            busy      <= 1'b0;
        end
        default: begin
          state     <= WAIT;
          clk_cnt   <= 32'h0000_0000;
          rx_index  <= 3'b000;
          irq       <= 1'b0;
          rx_data   <= 8'h0;
          frame_err <= 1'b0;
          busy      <= 1'b0;
          buf_data  <= 8'h0;
        end
      endcase
    end
  end

endmodule