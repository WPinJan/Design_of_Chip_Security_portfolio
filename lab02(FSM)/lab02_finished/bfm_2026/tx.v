module transmitter#(
parameter NAME = "transmitter",
parameter WIDTH_OF_LEN = 64,
parameter WIDTH_OF_BE  = 4,
parameter WORD_SIZE    = 32,
parameter WORD_NUMB    = 40,
parameter DGST_NUMB    = 11
)(
output reg  [ WIDTH_OF_LEN-1:0] msg_len,
output reg  [ WORD_SIZE   -1:0] msg_dat,
output reg  [ WIDTH_OF_BE -1:0] msg_be,
output reg           start_p,
output reg           msg_lst,
output reg           msg_vld,

input                msg_rdy,

input                clk,
input                rst_n
);
////////////////////////////
//DECLARITION
////////////////////////////
integer              i;

//memory in transmitter
reg [ WORD_SIZE   -1:0] mem_msg_dat[0: WORD_NUMB -1];
reg [ WIDTH_OF_BE -1:0] mem_msg_be [0: WORD_NUMB -1];
reg [ WIDTH_OF_LEN-1:0] mem_msg_len[0: DGST_NUMB -1];
reg                     mem_msg_lst[0: WORD_NUMB -1];


////////////////////////////
//TRANSMITTER TASK
////////////////////////////
//laod vectors into tx mem.
task load_test_dat;
	input [ 32-1:0] addr;
	input [ WORD_SIZE-1:0] data;
	begin
		mem_msg_dat[addr] = data;
//		$display ($time, ,"(%s) load msg_dat = 8'h%8h into mem_msg_dat[0x%8h]", NAME, data, addr);
	end
endtask

task load_msg_be;
	input [ 32-1:0] addr;
	input [ WIDTH_OF_BE-1:0] data;
	begin
		mem_msg_be[addr] = data;
//		$display ($time, ,"(%s) load msg_be = 4'b%4b into mem_msg_be[0x%8h]", NAME, data, addr);
	end
endtask

task load_msg_len;
	input [ 32-1:0] addr;
	input [ WIDTH_OF_LEN-1:0] data;
	begin
		mem_msg_len[addr] = data;
//		$display ($time, ,"(%s) load msg_len = 16'h%16h into mem_msg_len[0x%8h]", NAME, data, addr);
	end
endtask

task load_msg_lst;
	input [ 32-1:0] addr;
	input data;
	begin
		mem_msg_lst[addr] = data;
//		$display ($time, ,"(%s) load msg_lst = %1h into mem_msg_lst[0x%8h]", NAME, data, addr);
	end
endtask

//setup config.

////// tx mission //////
//start_p protocol
task  start;
   input [32-1:0] msg_cnt;
   begin
      @(posedge clk);
      msg_len  <= mem_msg_len[msg_cnt-1];
      start_p  <= 1;
      @(posedge clk);
      msg_len  <= 0;
      start_p  <= 0;
      $display($time,,"(%s) write msg_len = 16'h%16h and start %3d message hash function",NAME, mem_msg_len[msg_cnt-1], msg_cnt);
   end
endtask

//write protocol
task first_write;
	input integer msg_cnt;
	output integer cnt;
	begin
		cnt = 0;
		for(int i = 0; i < msg_cnt-1; i = i+1) begin
			cnt = cnt + mem_msg_len[i][WIDTH_OF_LEN-1:5];
			if (mem_msg_len[i][4:0] != 0)
				cnt = cnt + 1;
		end
		@(posedge clk);
		msg_dat <= mem_msg_dat[cnt];
		msg_be  <= mem_msg_be[cnt];
		msg_lst <= mem_msg_lst[cnt];
		msg_vld <= 1;
		$display($time,,"(%s) write msg_dat = 8'h%8h",NAME ,mem_msg_dat[cnt]);
	end
endtask

task handshake_and_write;
	input integer cnt;
	input integer prob;			//prob. to pause valid signal
	begin
		@(posedge clk);
		while (~msg_rdy) begin
			@(posedge clk);
		end
		$display($time,,"(%s) handshake success", NAME);
		i = 0;
		while(i==0) begin
			if((($random % 100) + 100) % 100 < prob) begin
				msg_vld <= 0;
				@(posedge clk);
			end else begin
				msg_dat <= mem_msg_dat[cnt];
				msg_be  <= mem_msg_be[cnt];
				msg_lst <= mem_msg_lst[cnt];
				msg_vld <= 1;
				$display($time,,"(%s) write msg_dat = 8'h%8h",NAME ,mem_msg_dat[cnt]);
				i = i + 1;
			end
		end
	end
endtask

task end_writing;
	begin
		@(posedge clk);
		while (~msg_rdy) begin
			@(posedge clk);
		end
		$display($time,,"(%s) handshake success", NAME);
		msg_vld <= 0;
		msg_lst <= 0;
	end
endtask


//get length
task  get_len;
	input  [32-1:0] msg_cnt;	
   	output [WIDTH_OF_LEN-1:0] len;
   	begin
		len = mem_msg_len[msg_cnt-1];
	end
endtask


//initial value
initial begin
   start_p   = 0;
   msg_len   = 0;
   msg_vld   = 0;
   msg_dat   = 0;
   msg_be    = 0;
   msg_lst   = 0;
end

endmodule
