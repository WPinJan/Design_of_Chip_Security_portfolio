module reciever#(
parameter NAME = "receiver"
)(
input    [ 255:0] rx_data,
output            rx_busy,

input             dgst_done,
input             start_p,
output            dgst_vld,


input             clk,
input             rst_n
);
//
//
////////////////////////////
//DECLARITION
////////////////////////////
//state
localparam ST_IDLE = 1'b0;
localparam ST_RCVD = 1'b1;

reg         state;
reg         state_next; 

//control
wire        clr;
reg [ 31:0] cnt_clk;
reg [ 31:0] cnt_data;

//setup configuration
reg [ 31:0] cfg_length;//length
reg         run_en;
reg         dgst_vld_r;


////////////////////////////
//TASK: SETUP CONFIGURATION
////////////////////////////
//length of received data
task setcfg_length;
   input    [31:0]   length;
   begin
      cfg_length = length;
      $display($time,,"(%s) setup cfg_length = %1d",NAME,length);
   end
endtask

//start=1, to trigger state machine to receive data
task start;
   input    start_bit;
   begin
      @(posedge clk);
      run_en     <= start_bit;
      @(posedge clk);
      run_en     <= 0;
   end
endtask

////////////////////////////
//ASSIGNMENT
////////////////////////////
//transmitter signals
assign rx_busy = state!=ST_IDLE;
assign dgst_vld = dgst_vld_r;
initial begin
   dgst_vld_r = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
	  if (dgst_done) dgst_vld_r <= 1;
	  else if (start_p) dgst_vld_r <= 0;
	  else dgst_vld_r <= dgst_vld_r;
   end
end
//next state
always@*begin
   state_next = state;

   case(state)
      ST_IDLE: if(run_en)                        state_next = ST_RCVD;      
      ST_RCVD: if(cnt_data==cfg_length)    state_next = ST_IDLE;
   endcase
end

////////////////////////////
//Initial
////////////////////////////
//default value
initial begin
   cfg_length      = 0;
   run_en          = 0;
end
//state
initial begin
   state = ST_IDLE;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      state <= state_next;
   end
end

//
assign clr = state==ST_IDLE && run_en;
//

//counter: count received data
initial begin
   cnt_data = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_data <= 0;
      else if(state==ST_RCVD && dgst_done) cnt_data <= cnt_data+1;
   end
end


endmodule
