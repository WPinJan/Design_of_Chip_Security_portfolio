module receiver#(
parameter NAME = "receiver",
parameter DGST_SIZE = 256
)(
input [DGST_SIZE-1:0] dgst,
input                 dgst_done,

input                 clk,
input                 rst_n
);
////////////////////////////
//RECEIVER TASK
////////////////////////////

task read_at_done;
   output [DGST_SIZE-1:0] data;
   begin
      @(posedge clk);
      while(~dgst_done) begin
         @(posedge clk);
      end
      data = dgst;
	  $display ($time, ,"(%s) read dgst = %64h at done", NAME, data);
   end
endtask

task read;
   output [DGST_SIZE-1:0] data;
   begin
      @(posedge clk);
      data = dgst;
	  $display ($time, ,"(%s) read dgst = %64h before start_p", NAME, data);
   end
endtask


endmodule
