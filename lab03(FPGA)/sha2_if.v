module sha2_if(
	//from AXI reg
   input  [ 32-1:0] mustang,   //start_vld_len_lst 
   input  [ 32-1:0] in_be,
   input  [ 32-1:0] data_0,
   input  [ 32-1:0] data_1,
   input  [ 32-1:0] data_2,
   input  [ 32-1:0] data_3,
   input  [ 32-1:0] data_4,
   input  [ 32-1:0] data_5,
   input  [ 32-1:0] data_6,
   input  [ 32-1:0] data_7,
	//from DUT
   input            msg_rdy,
   input            dgst_done,
   input  [256-1:0] dgst,
   	//to AXI reg
   output [ 32-1:0] dgst_vld,
   output [ 32-1:0] result_0,
   output [ 32-1:0] result_1,
   output [ 32-1:0] result_2,
   output [ 32-1:0] result_3,
   output [ 32-1:0] result_4,
   output [ 32-1:0] result_5,
   output [ 32-1:0] result_6,
   output [ 32-1:0] result_7,
   	//to DUT
   output           start_p,
   output [ 64-1:0] msg_len,
   output           msg_vld,
   output [ 32-1:0] msg_dat,
   output [  4-1:0] msg_be,
   output           msg_lst,

   input            rst_n,
   input            clk
);


////////////////////////////
//DECLARITION
////////////////////////////
//state
localparam IDLE   = 3'b000;
localparam START  = 3'b001;
localparam SEND   = 3'b010;
localparam WDONE  = 3'b011;
localparam WSTART = 3'b100;

reg  [ 2:0] state;
reg  [ 2:0] state_nx; 

//counter
wire [ 3:0] msg_word;   //這個msg有幾個word？
reg  [ 3:0] cnt_word;   //已經傳了幾個word了

//message package
wire [31:0] data [0:7];
wire [ 3:0] be   [0:7];
wire        start_l;
wire        vld;
wire [63:0] len;        //有幾個byte？這次的spec是只有32 byte
wire [ 7:0] lst;

///////////////////////
//FSM
///////////////////////
//setting next state
always@(posedge clk or negedge rst_n)begin
   if(~rst_n)  state <= IDLE;
   else        state <= state_nx;
end

//decision of next state
always@*begin
   state_nx = state;
   case(state)
       IDLE   : if(start_l)       state_nx = START; 
	   START  : if(len==0)      state_nx = WDONE;
                else            state_nx = SEND;
       SEND   : if(msg_rdy && cnt_word == msg_word - 4'b1) state_nx = WDONE;
       WDONE  : if(dgst_done)   state_nx = WSTART;
	   WSTART : if(start_l)       state_nx = START; 
       default: state_nx = state;
   endcase
end


////////////////////////////
//ASSIGNMENT
////////////////////////////
//package input signal
assign start_l = mustang[0];
assign vld   = mustang[1];
assign len   = {55'b0, mustang[7:2], 3'b0};
assign lst   = mustang[15:8];
assign be[0] = in_be[3:0];
assign be[1] = in_be[7:4];
assign be[2] = in_be[11:8];
assign be[3] = in_be[15:12];
assign be[4] = in_be[19:16];
assign be[5] = in_be[23:20];
assign be[6] = in_be[27:24];
assign be[7] = in_be[31:28];
assign data[0] = data_0;
assign data[1] = data_1;
assign data[2] = data_2;
assign data[3] = data_3;
assign data[4] = data_4;
assign data[5] = data_5;
assign data[6] = data_6;
assign data[7] = data_7;

//output to DUT
assign start_p = state == START;
assign msg_len = (start_p) ? len : 64'b0;
assign msg_vld = (state == SEND) ? vld : 0;
assign msg_dat = (msg_vld) ? data[cnt_word] : 32'b0;
assign msg_be  = (msg_vld) ? be[cnt_word] : 4'b0;
assign msg_lst = (msg_vld) ? lst[cnt_word] : 1'b0;

//output to AXI
assign dgst_vld[31] = state == WSTART;
assign dgst_vld[30] = state == WDONE;
assign result_0 = dgst[ 31:  0];
assign result_1 = dgst[ 63: 32];
assign result_2 = dgst[ 95: 64];
assign result_3 = dgst[127: 96];
assign result_4 = dgst[159:128];
assign result_5 = dgst[191:160];
assign result_6 = dgst[223:192];
assign result_7 = dgst[255:224];

//how many words? 0~8

wire [5:0] word_raw;
assign word_raw = mustang[7:2] >> 2;
assign msg_word = (mustang[3:2] == 0) ? word_raw[3:0] : (word_raw[3:0] + 1) ; //這個msg有幾個word？

////////////////////
//counter
////////////////////
assign cnt_en = msg_vld && msg_rdy;
assign cnt_0  = state == START ;

always@(posedge clk or negedge rst_n)begin
   if(~rst_n)     cnt_word <= 4'h0;
   else if(cnt_0) cnt_word <= 4'h0;
   else           cnt_word <= cnt_en? cnt_word + 4'd1: cnt_word;
end


endmodule
