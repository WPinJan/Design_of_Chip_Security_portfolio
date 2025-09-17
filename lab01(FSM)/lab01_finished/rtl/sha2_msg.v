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
localparam CAL_1 = 2'b01;
localparam CAL_2 = 2'b10;
localparam ST_TRANSMIT = 2'b11;

reg   [1:0] state;
reg   [1:0] state_nx;

//control signals
wire        in_hs;
wire        out_hs;

//count index of data input, maximum count 64
reg   [5:0] cnt;               //include recieve and transmit counter
wire  [5:0] cnt_next;
wire        cnt_en;
wire        cnt_0;
wire        cnt_next_full;     //w0-w64 are transmitted
//wire        cnt_next_16;       //w0-w15 are filled

//massage 32-bit data array
reg   [31:0] word_schedule[0:15];

//other calculation
genvar i;
wire  [31:0] sigma_1_w14;
wire  [31:0] sigma_0_w1;


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
   ST_RECIEVE  : if(cnt_next[4])        state_nx = ST_TRANSMIT;
   ST_TRANSMIT : if(word_rdy) begin
                      if(cnt_next_full)  state_nx = ST_RECIEVE;
					  else               state_nx = CAL_1;
				  end
				  else   state_nx = ST_TRANSMIT;
   CAL_1    : state_nx = CAL_2;
   CAL_2    : state_nx = ST_TRANSMIT;
   default      :state_nx = state;

   endcase
end

//output controlled by FSM
assign msg_rdy = (state == ST_RECIEVE);
assign word_vld = (state == ST_TRANSMIT);
assign word = word_schedule[0];                    //不確定是否需要加上state的限制



//controll signal
assign in_hs = msg_rdy && msg_vld;       //input handshake success
assign out_hs = word_rdy && word_vld;    //output handshake success

//counter
assign cnt_en        = in_hs || out_hs;  //also be propagation indicator
assign cnt_0         = cnt_next[4] && in_hs;       //cnt_next_full && out_hs
assign cnt_next      = cnt_en? cnt+6'd1: cnt;
assign cnt_next_full = &cnt;                 // 其實cnt_next還不一定full，但FSM已經有過濾(word_rdy)的條件了(也就代表cnt_next確實full了)
//assign cnt_next_16   = cnt_next[4];                // 因為我的FSM design中ST_TRANS只有一個條件(不足)

always@(posedge clk or negedge rst_n)begin
   if(~rst_n)     cnt <= 6'h0;
   else if(cnt_0) cnt <= 6'h0;
   else           cnt <= cnt_next;
end

///////////////////////
//data array
///////////////////////
//心得:一個always block處理一種訊號
//word_schedule[0]-[13]
generate
	for(i=0; i<15; i=i+1) begin: WORD_PROPAGATE
		always@(posedge clk or negedge rst_n)begin
			if(~rst_n)        word_schedule[i] <= 32'd0;
			else if( cnt_en ) word_schedule[i] <= word_schedule[i+1];  //(in || out)
			else              word_schedule[i] <= word_schedule[i];
		end
	end
endgenerate

//Rotation function
function [31:0] rotr;
  input [31:0] x;
  input [4:0] n;  // shift amount, 5 bits for 0~31
  begin
    rotr = (x >> n) | (x << (32 - n));
  end
endfunction



//word_schedule[15]
assign sigma_0_w1  = (rotr(word_schedule[0], 7) ^ rotr(word_schedule[0], 18) ^ (word_schedule[0] >> 3)); 
assign sigma_1_w14 = (rotr(word_schedule[14], 17 ) ^ rotr(word_schedule[14], 19) ^ (word_schedule[14] >> 10));  
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)    word_schedule[15] <= 32'd0;
	else begin
		case(state)
			ST_RECIEVE  : if(msg_vld)  word_schedule[15] <= msg_dat;
            ST_TRANSMIT : if(word_rdy) word_schedule[15] <= sigma_1_w14 + word_schedule[0];
			CAL_1    : word_schedule[15] <= word_schedule[15] + word_schedule[8];
			CAL_2    : word_schedule[15] <= word_schedule[15] + sigma_0_w1;
			default     : word_schedule[15] <= word_schedule[15];
		endcase
	end
end



endmodule

