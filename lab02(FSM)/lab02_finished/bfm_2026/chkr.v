module checker#(
parameter NAME = "checker",
parameter DGST_SIZE = 256,
parameter DGST_NUMB = 11
)(
input                 clk,
input                 rst_n
);
////////////////////////////
//DECLARITION
////////////////////////////
reg [31:0] cnt_pass;
reg [31:0] cnt_fail;

//memory in checker
reg [DGST_SIZE-1:0] mem_exp_dat [0:DGST_NUMB-1];

////////////////////////////
//CHECKER TASK
////////////////////////////
task load_exp_dat;
	input [ 32-1:0] addr;
	input [ DGST_SIZE-1:0] data;
	begin
		mem_exp_dat[addr] = data;
		$display ($time, ,"(%s) load dgst = %64h into mem_msg_dat[0x%8h]", NAME, data, addr);
	end
endtask

task compare;
	input integer cnt;
   	input [DGST_SIZE-1:0] rd;
   	begin
      	if(rd !== mem_exp_dat[cnt-1]) begin
         	cnt_fail <= cnt_fail + 1;
         	$display($time,,"ERROR, digest %h", rd);
         	$display($time,,"    != expect %h", mem_exp_dat[cnt-1]);
      	end else begin
			cnt_pass <= cnt_pass + 1;
			$display($time,,"PASS, digest %h", rd);
         	$display($time,,"    = expect %h", mem_exp_dat[cnt-1]);
		end
   	end
endtask

task get_pass_cnt;
	output integer passcnt;
	begin
		@(posedge clk);
		passcnt = cnt_pass;
	end
endtask

task get_fail_cnt;
	output integer failcnt;
	begin
		@(posedge clk);
		failcnt = cnt_fail;
	end
endtask


//initial value
initial begin
	cnt_pass = 0;
	cnt_fail = 0;
end

endmodule
