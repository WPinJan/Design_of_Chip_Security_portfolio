module sha2_msg(
   input               msg_vld,
   input      [31:0]   msg_dat,
   output              msg_rdy,
   output              word_vld,
   output     [31:0]   word,
   input               word_rdy,
   input               rst_n,
   input               clk
);

  // State encoding
  localparam ST_RECIEVE  = 2'b00;
  localparam ST_T1CAL    = 2'b01;
  localparam ST_T2CAL    = 2'b10;
  localparam ST_TRANSMIT = 2'b11;

  reg  [1:0]  state, state_nx;
  reg  [5:0]  cnt;
  wire [5:0]  cnt_next;
  reg [31:0] word_reg [0:15];
  integer i;
  wire        in_hs  = msg_rdy  && msg_vld;
  wire        out_hs = word_rdy && word_vld;
  wire sigma_0;
  wire sigma_1;

  assign msg_rdy  = (state == ST_RECIEVE);
  assign word_vld = (state == ST_TRANSMIT);
  assign word     = word_reg[0];

  wire cnt_en        = in_hs || out_hs;
  wire cnt_rst       = (state == ST_TRANSMIT && cnt == 6'd63 && out_hs) || (state == ST_RECIEVE && cnt == 6'd15 && in_hs);
  assign cnt_next    = cnt_en ? cnt + 6'd1 : cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 6'd0;
    else if (cnt_rst) cnt <= 6'd0;
    else cnt <= cnt_next;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= ST_RECIEVE;
    else        state <= state_nx;
  end

  always @(*) begin
    case (state)
      ST_RECIEVE : state_nx = (cnt_next == 6'd16) ? ST_T1CAL : ST_RECIEVE;
      ST_T1CAL   : state_nx = ST_T2CAL;
      ST_T2CAL   : state_nx = ST_TRANSMIT;
      ST_TRANSMIT: state_nx = (out_hs && cnt == 6'd63) ? ST_RECIEVE : (out_hs ? ST_T1CAL : ST_TRANSMIT);
      default    : state_nx = ST_RECIEVE;
    endcase
  end

  // Transient word register
  reg [31:0] trans_word;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) trans_word <= 32'd0;
    else begin
      case (state)
        ST_T1CAL    : trans_word <= sigma_0 + sigma_1;
        ST_T2CAL    : trans_word <= trans_word + word_reg[0];
        ST_TRANSMIT : if (out_hs) trans_word <= trans_word + word_reg[9];
      endcase
    end
  end
  // Shift register for word_schedule


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) word_reg[i] <= 32'd0;
    end else if (in_hs || out_hs) begin
      for (i = 0; i < 15; i = i + 1)
        word_reg[i] <= word_reg[i+1];

      if (state == ST_RECIEVE && in_hs)         word_reg[15] <= msg_dat;
      else if (state == ST_T1CAL && cnt != 0)   word_reg[15] <= trans_word;
    end
  end

  // Rotation function
  function [31:0] rotr;
    input [31:0] x;
    input [4:0] n;
    begin
      rotr = (x >> n) | (x << (32 - n));
    end
  endfunction

  // Sigma logic (combinational)
  assign sigma_0 = rotr(word_reg[1], 7) ^ rotr(word_reg[1], 18) ^ (word_reg[1] >> 3);
  assign sigma_1 = rotr(word_reg[14], 17) ^ rotr(word_reg[14], 19) ^ (word_reg[14] >> 10);
  


endmodule






module sha2_msg(
   input               msg_vld,
   input      [32-1:0] msg_dat,
   output              msg_rdy,
   output              word_vld,
   output     [32-1:0] word,
   input               word_rdy,
   input               rst_n,
   input               clk
);

///////////////////////
//DECLARATION
///////////////////////
//state
localparam ST_RECIEVE = 2'b00;
localparam ST_T1CAL = 2'b01;
localparam ST_T2CAL = 2'b10;
localparam ST_TRANSMIT = 2'b11;

reg   [1:0] state;
reg   [1:0] state_nx;               //寫不寫reg有差嗎？

//control signals
wire        in_hs;
wire        out_hs;

//count index of data input, maximum count 64
reg   [5:0] cnt;               //include recieve and transmit counter
wire  [5:0] cnt_next;
wire        cnt_en;
wire        cnt_rst;
wire        cnt_0;
wire        cnt_next_full;     //w0-w64 are transmitted
wire        cnt_next_16;       //w0-w15 are filled

//massage 32-bit data array
reg   [31:0] word_schedule[0:15];
//register for transient value and word to transmit
reg   [31:0] trans_word;
//reg   [31:0] trans_t1;
//other calculation
wire  [31:0] sigma_1_w14;
wire  [31:0] sigma_0_w1;
genvar i;


///////////////////////
//FSM
///////////////////////
//setting next state
always@(posedge clk or negedge rst_n)begin
   if(~rst_n)  state <= ST_RECIEVE;
   else        state <= state_nx;
end

//decision of next state
always@(*)begin
   state_nx = state;
   case(state)
   ST_RECIEVE  : if(cnt_next_16)        state_nx = ST_T1CAL;
   				  else                   state_nx = ST_RECIEVE; 
   ST_T1CAL    : state_nx = ST_T2CAL;
   ST_T2CAL    : state_nx = ST_TRANSMIT;
   ST_TRANSMIT : if(word_rdy) begin
                      if(cnt_next_full)  state_nx = ST_RECIEVE;
					  else               state_nx = ST_T1CAL;
				  end
				  else   state_nx = ST_TRANSMIT;
   default      :state_nx = ST_RECIEVE;

   endcase
end

//output controlled by FSM
assign msg_rdy = (state == ST_RECIEVE);
assign word_vld = (state == ST_TRANSMIT);
assign word = word_schedule[0];                    //不確定是否需要加上state的限制

//controll signal
assign in_hs = msg_rdy && msg_vld;       //input handshake success
assign out_hs = word_rdy && word_vld;    //output handshake success

///////////////////////
//data array
///////////////////////
//心得:一個always block處理一種訊號
//word_schedule[0]-[14]
generate
	for(i=0; i<15; i=i+1) begin: WORD_PROPAGATE
		always@(posedge clk or negedge rst_n)begin
			if(~rst_n)        word_schedule[i] <= 32'd0;
			else if( in_hs || out_hs ) word_schedule[i] <= word_schedule[i+1];  //(in || out)
			else              word_schedule[i] <= word_schedule[i];
		end
	end
endgenerate


//word_schedule[15]
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)           word_schedule[15] <= 32'd0;
	else begin
		case(state)
		    ST_RECIEVE  : if(in_hs)  word_schedule[15] <= msg_dat;
			ST_T1CAL    : if(cnt!=0) word_schedule[15] <= trans_word;  //added
//    		ST_TRANSMIT : if(out_hs) word_schedule[15] <= trans_word + word_schedule[9];
		    default     : word_schedule[15] <= word_schedule[15];
	    endcase
	end
end

//trans_word
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)    trans_word <= 32'd0;
	else begin
		case(state)
			ST_T1CAL : trans_word <= sigma_0_w1 + sigma_1_w14;
			ST_T2CAL : trans_word <= trans_word + word_schedule[0];
			ST_TRANSMIT : if(out_hs) trans_word <= trans_word + word_schedule[9]; //added
			default  : trans_word <= trans_word;
		endcase
	end
end

//Rotation function
function [31:0] rotr;
  input [31:0] x;
  input [4:0] n;  // shift amount, 5 bits for 0~31
  begin
    rotr = (x >> n) | (x << (32 - n));
  end
endfunction

//sigma calculate

assign sigma_1_w14 = rotr(word_schedule[14], 17 ) ^ rotr(word_schedule[14], 19) ^ (word_schedule[14] >> 10);
assign sigma_0_w1 = rotr(word_schedule[1], 7) ^ rotr(word_schedule[1], 18) ^ (word_schedule[1] >> 3);

//counter
assign cnt_en        = in_hs || out_hs;
assign cnt_0         = cnt_next_16 && in_hs;     //cnt_next_full && out_hs
assign cnt_next      = cnt_en? cnt+6'd1: cnt;
assign cnt_next_full = cnt == 6'd63;    //cnt_next == 6'd64 ??????????
assign cnt_next_16   = cnt_next == 6'd16;    //cnt == 6'd63   因為我的FSM design中ST_TRANS只有一個條件(不足)

always@(posedge clk or negedge rst_n)begin
   if(~rst_n)     cnt <= 6'h0;
   else if(cnt_0) cnt <= 6'h0;
   else           cnt <= cnt_next;
end


endmodule
