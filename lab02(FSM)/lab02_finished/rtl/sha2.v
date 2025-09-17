module sha2(
   input            start_p,
   input  [ 64-1:0] msg_len,
   input            msg_vld,
   input  [ 32-1:0] msg_dat,
   input  [  4-1:0] msg_be,
   input            msg_lst,
   output           msg_rdy,
   output           dgst_done,
   output [256-1:0] dgst,
   input            rst_n,
   input            clk
);

///////////////////////
//DECLARATION
///////////////////////
//state
localparam IDLE          = 4'b0000;
localparam RECEIVE       = 4'b0001;
localparam PAD_SH        = 4'b0010;
localparam CPS_LOAD      = 4'b0011;
localparam CPS_ADDEXP    = 4'b0100;
localparam HASH_UPDATE_0 = 4'b0101;
localparam HASH_UPDATE_1 = 4'b0110;
localparam HASH_UPDATE_2 = 4'b0111;
localparam HASH_UPDATE_3 = 4'b1000;
localparam HASH_UPDATE_4 = 4'b1001;
localparam HASH_UPDATE_5 = 4'b1010;
localparam HASH_UPDATE_6 = 4'b1011;
localparam HASH_UPDATE_7 = 4'b1100;
localparam DONE          = 4'b1101;

reg   [3:0] state;
reg   [3:0] state_nx;

//control signals
wire        in_hs;
wire        pad_shift;
wire        exp_shift;
wire        update;

//wire [31:0] msg_en;
//wire [31:0] msg_dat_s;

reg         msg_lst_r;
reg  [60:0] msg_len_r;
reg         begin_with;
reg         come_back;

//count index of data input and exp/cps round, maximum count 64
reg   [5:0] cnt;
wire  [5:0] cnt_next;
wire        cnt_en;
wire        cnt_0;
wire        cnt_full;     //r0-r64 are transmitted
wire        cnt_16;       //r0-r15 are filled

//massage 32-bit data array
reg   [31:0] msg[0:15];

//k 32-bit data array
wire  [31:0] k;

//hash value 32-bit data array
reg   [31:0] h[0:7];

wire  [31:0] h_0[0:7];

//work variables value 32-bit data array
reg   [31:0] w[0:7];

//other calculation
genvar i;
wire  [31:0] sigma_1_msg14;
wire  [31:0] sigma_0_msg1;
wire  [31:0] ch_efg;
wire  [31:0] maj_abc;
wire  [31:0] sigmab_1_w4;
wire  [31:0] sigmab_0_w0;

///////////////////////
//FSM
///////////////////////
//setting next state
always@(posedge clk or negedge rst_n)begin
   if(~rst_n)  state <= IDLE;
   else        state <= state_nx;
end

//decision of next state
always@(*)begin
   state_nx = state;
   case(state)
   IDLE       : if (start_p) begin
                  if (msg_len==0) state_nx = PAD_SH;
                  else            state_nx = RECEIVE;
		    	end
   RECEIVE    : if (cnt_16)    state_nx = CPS_LOAD;    //注意有msg_vld嗎
                else begin
			  	  if (msg_lst) state_nx = PAD_SH;
			 	  else         state_nx = RECEIVE;
			    end
   PAD_SH     : if (cnt_16)    state_nx = CPS_LOAD;
			    else           state_nx = PAD_SH;
   CPS_LOAD   :                state_nx = CPS_ADDEXP;
   CPS_ADDEXP : if (cnt_full)  state_nx = HASH_UPDATE_0;
                else           state_nx = CPS_ADDEXP;
   HASH_UPDATE_0:              state_nx = HASH_UPDATE_1;
   HASH_UPDATE_1:              state_nx = HASH_UPDATE_2;
   HASH_UPDATE_2:              state_nx = HASH_UPDATE_3;
   HASH_UPDATE_3:              state_nx = HASH_UPDATE_4;
   HASH_UPDATE_4:              state_nx = HASH_UPDATE_5;
   HASH_UPDATE_5:              state_nx = HASH_UPDATE_6;
   HASH_UPDATE_6:              state_nx = HASH_UPDATE_7;
   HASH_UPDATE_7: if (come_back)     state_nx = PAD_SH;
                  else if(msg_lst_r) state_nx = DONE;
				  else               state_nx = RECEIVE;
   DONE       :                state_nx = IDLE;
   default    :                state_nx = state;
   endcase
end

//output controlled by FSM
assign msg_rdy = (state == RECEIVE);
assign dgst = {h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]};
assign dgst_done = (state == DONE);

//signal controlled by FSM
assign in_hs = msg_rdy && msg_vld;       //input handshake success
assign pad_shift = (state == PAD_SH);
assign exp_shift = (state == CPS_ADDEXP);
assign update    = (state == HASH_UPDATE_7);

////////////////////
//counter
////////////////////
assign cnt_en   = (in_hs | pad_shift | exp_shift);
assign cnt_0    = cnt_next[4] && (in_hs | pad_shift);
assign cnt_next = cnt_en? cnt+6'd1: cnt;
assign cnt_full = &cnt;                 // 
assign cnt_16   = cnt_next[4];          // 因為我的RECEIVE時next state的判斷只有一個條件(不足)

always@(posedge clk or negedge rst_n)begin
   if(~rst_n)     cnt <= 6'h0;
   else if(cnt_0) cnt <= 6'h0;
   else           cnt <= cnt_next;
end

///////////////////////
//function
///////////////////////
//Rotation function
function [31:0] rotr;
  input [31:0] x;
  input [4:0] n;  // shift amount, 5 bits for 0~31
  begin
    rotr = (x >> n) | (x << (32 - n));
  end
endfunction

//CH function
function [31:0] ch;
  input [31:0] x;
  input [31:0] y;
  input [31:0] z;
  begin
    ch = (x & y) ^ (~x & z);
  end
endfunction

//MAJ function
function [31:0] maj;
  input [31:0] x;
  input [31:0] y;
  input [31:0] z;
  begin
    maj = (x & y) ^ (x & z) ^ (y & z);
  end
endfunction

assign sigma_0_msg1  = (rotr(msg[1], 7) ^ rotr(msg[1], 18) ^ (msg[1] >> 3));
assign sigma_1_msg14 = (rotr(msg[14], 17 ) ^ rotr(msg[14], 19) ^ (msg[14] >> 10));
assign sigmab_0_w0    = (rotr(w[0], 2) ^ rotr(w[0], 13) ^ rotr(w[0], 22));
assign sigmab_1_w4    = (rotr(w[4], 6 ) ^ rotr(w[4], 11) ^ rotr(w[4], 25));
assign ch_efg        = ch(w[4], w[5], w[6]);
assign maj_abc       = maj(w[0], w[1], w[2]);

///////////////////////
//control signal
///////////////////////
//come back to padding or not
always@(posedge clk or negedge rst_n)begin
   if(~rst_n)     come_back <= 1'b0;
   else if(msg_rdy && msg_lst && (cnt_16 || cnt_next==6'd15 || (cnt_next==6'd14 && msg_be==4'hf))) come_back <= 1'b1;
   else if(update) come_back <= 1'b0;
   else           come_back <= come_back;
end

//the padding word begin with 1 or 0
always@(posedge clk or negedge rst_n)begin
	if(~rst_n)     begin_with <= 1'b0;
	else if((msg_rdy && msg_lst && msg_be==4'hf) || (start_p && msg_len==0)) begin_with <= 1'b1;  
	else if(pad_shift) begin_with <= 1'b0;
    else            begin_with <= begin_with;
end

///////////////////////
//input register
///////////////////////
//massage length reg
always@(posedge clk or negedge rst_n)begin
	if(~rst_n)       msg_len_r <= 61'b0;
	else if(start_p) msg_len_r <= msg_len[63:3];
    else             msg_len_r <= msg_len_r;
end

//massage last reg
always@(posedge clk or negedge rst_n)begin
	if(~rst_n)       msg_lst_r <= 1'b0;
	else if(in_hs)   msg_lst_r <= msg_lst;
	else if(start_p && msg_len==0) msg_lst_r <= 1'b1;
    else             msg_lst_r <= msg_lst_r;
end

///////////////////////
//data array
///////////////////////
//msg[0]-[14]
generate
	for(i=0; i<15; i=i+1) begin: MSG_PROPAGATE
		always@(posedge clk or negedge rst_n)begin
			if (~rst_n)       msg[i] <= 32'd0;
			else if (cnt_en)  msg[i] <= msg[i+1];   //cnt_en = shift_en
			else              msg[i] <= msg[i];
		end
	end
endgenerate

//msg[15]
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)    msg[15] <= 32'h00000000;
	else begin
		case(state)
			RECEIVE   : if(msg_vld) begin
			                case(msg_be)
								4'hf   : msg[15] <= msg_dat;
								4'he   : msg[15] <= {msg_dat[31:8], 1'b1, 7'b0};
							    4'hc   : msg[15] <= {msg_dat[31:16], 1'b1, 15'b0};
								4'h8   : msg[15] <= {msg_dat[31:24], 1'b1, 23'b0};
								default: msg[15] <= msg[15];
							endcase
						end
            PAD_SH    : if(begin_with)     msg[15] <= 32'h80000000;
			            else if(come_back) msg[15] <= 32'h00000000;           //如果還有需要come_back就不能給出length
		                else if( cnt==14 ) msg[15] <= msg_len_r[60:29];
						else if( cnt==15 ) msg[15] <= {msg_len_r[28:0],3'b0};
						else msg[15] <= 32'h00000000;
			CPS_ADDEXP: msg[15] <= msg[0] + sigma_0_msg1 + sigma_1_msg14 + msg[9];
			default   : msg[15] <= msg[15];
		endcase
	end
end

sha_k_rom k_rom (
    .addr(cnt),
    .k_value(k)
);

//a
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)    w[0] <= 32'h00000000;
	else begin
    case(state)
            CPS_LOAD  : w[0] <= h[0];
			CPS_ADDEXP: w[0] <= msg[0] + w[7] + k + sigmab_1_w4 + ch_efg + sigmab_0_w0 + maj_abc;
			default   : w[0] <= w[0];
		endcase
	end
end

//e
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)    w[4] <= 32'h00000000;
	else begin
		case(state)
            CPS_LOAD  : w[4] <= h[4];
			CPS_ADDEXP: w[4] <= w[3] + msg[0] + w[7] + k + sigmab_1_w4 + ch_efg ;
			default   : w[4] <= w[4];
		endcase
	end
end

//bcd
generate
	for(i=1; i<4; i=i+1) begin: BCD
		always@(posedge clk or negedge rst_n)begin
			if (~rst_n)       w[i] <= 32'd0;
			else begin
            case(state)
                 CPS_LOAD  : w[i] <= h[i];
			     CPS_ADDEXP: w[i] <= w[i-1];
			     default   : w[i] <= w[i];
		       endcase
        	end
	    end
	end
endgenerate

//fgh
generate
	for(i=5; i<8; i=i+1) begin: FGH
		always@(posedge clk or negedge rst_n)begin
			if (~rst_n)       w[i] <= 32'd0;
			else begin
		       case(state)
                 CPS_LOAD  : w[i] <= h[i];
			     CPS_ADDEXP: w[i] <= w[i-1];
			     default   : w[i] <= w[i];
		       endcase
        	end
	    end
	end
endgenerate

//h[0]-[7]
assign h_0[0] = 32'h6a09e667;
assign h_0[1] = 32'hbb67ae85;
assign h_0[2] = 32'h3c6ef372;
assign h_0[3] = 32'ha54ff53a;
assign h_0[4] = 32'h510e527f;
assign h_0[5] = 32'h9b05688c;
assign h_0[6] = 32'h1f83d9ab;
assign h_0[7] = 32'h5be0cd19;


reg [2:0] update_idx;

always @(*) begin
    case(state)
        HASH_UPDATE_0: update_idx = 3'd0;
        HASH_UPDATE_1: update_idx = 3'd1;
        HASH_UPDATE_2: update_idx = 3'd2;
        HASH_UPDATE_3: update_idx = 3'd3;
        HASH_UPDATE_4: update_idx = 3'd4;
        HASH_UPDATE_5: update_idx = 3'd5;
        HASH_UPDATE_6: update_idx = 3'd6;
        HASH_UPDATE_7: update_idx = 3'd7;
        default      : update_idx = 3'dx;
    endcase
end



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        h[0] <= h_0[0];
		h[1] <= h_0[1];
		h[2] <= h_0[2];
		h[3] <= h_0[3];
        h[4] <= h_0[4];
		h[5] <= h_0[5];
		h[6] <= h_0[6];
		h[7] <= h_0[7];
    end else begin
        if (state == IDLE && start_p) begin
        h[0] <= h_0[0];
		h[1] <= h_0[1];
		h[2] <= h_0[2];
		h[3] <= h_0[3];
        h[4] <= h_0[4];
		h[5] <= h_0[5];
		h[6] <= h_0[6];
		h[7] <= h_0[7];
        end else if (state == HASH_UPDATE_0 || state == HASH_UPDATE_1 ||
                     state == HASH_UPDATE_2 || state == HASH_UPDATE_3 ||
                     state == HASH_UPDATE_4 || state == HASH_UPDATE_5 ||
                     state == HASH_UPDATE_6 || state == HASH_UPDATE_7) begin
            h[update_idx] <= h[update_idx] + w[update_idx];
        end
    end
end

endmodule


