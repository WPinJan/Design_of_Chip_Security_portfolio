module reciever#(
parameter NAME = "receiver"
)(
input      [ 31:0] rx_data,
input             rx_vld,
output            rx_rdy,
output            rx_busy,

input             clk,
input             rst_n
);
//
//
////////////////////////////
//DECLARITION
////////////////////////////
//state
localparam ST_IDLE = 2'b00;
localparam ST_WAIT = 2'b01;
localparam ST_RCVD = 2'b10;//receive state
localparam ST_HOLD = 2'b11;

reg [ 1:0] state;
reg [ 1:0] state_next; 

//control
wire       clr;
reg [31:0] cnt_clk;
reg [31:0] cnt_data;
reg [31:0] cnt_hold;

//setup configuration
reg [31:0] cfg_length;//length
reg        cfg_pause_en;//pause enable
reg [31:0] cfg_pause_cycle;//pause rate
reg [31:0] pause_cycle;

reg        run_en;
reg [31:0] wait_cycle;//wait cycle

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
//pause enable: data valid with a pause rate
task setcfg_pause;
   input             enable;
   begin
      cfg_pause_en = enable;
      $display($time,,"(%s) setup cfg_pause_en = %1b",NAME,enable);
   end
endtask
//pause cycle: pause rate in a random range
task setcfg_pause_rate;
   input    [31:0]   clk_cycle;
   begin
      cfg_pause_cycle = clk_cycle;
      $display($time,,"(%s) setup cfg_pause_cycle = %1d",NAME,clk_cycle);
   end
endtask
//start=1, to trigger state machine to receive data
task start;
   input    start_bit;
   input    [31:0]   cycle;
   begin
      @(posedge clk);
      run_en     <= start_bit;
      wait_cycle <= cycle;
      @(posedge clk);
      run_en     <= 0;
      $display($time,,"(%s) start",NAME);
   end
endtask

////////////////////////////
//ASSIGNMENT
////////////////////////////
//transmitter signals
assign rx_busy = state!=ST_IDLE;
assign rx_rdy  = state==ST_RCVD;
//next state
always@*begin
   state_next = state;

   case(state)
      ST_IDLE: if(run_en) 
                  if(wait_cycle==0)              state_next = ST_RCVD;
                  else                           state_next = ST_WAIT;
      ST_WAIT: if(cnt_clk==wait_cycle-32'h1)     state_next = ST_RCVD;      
      ST_RCVD: if(rx_vld)
                  if(cnt_data==cfg_length-32'h1) state_next = ST_IDLE;
                  else if(cfg_pause_en)          state_next = ST_HOLD;
      ST_HOLD: if(cnt_hold==pause_cycle)         state_next = ST_RCVD;
   endcase
end

////////////////////////////
//Initial
////////////////////////////
//default value
initial begin
   cfg_length      = 0;
   cfg_pause_en    = 0;
   cfg_pause_cycle = 0;

   run_en          = 0;
   wait_cycle      = 0;
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

//counter: count wait cycle
initial begin
   cnt_clk = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_clk <= 0;
      else if(state==ST_WAIT) cnt_clk <= cnt_clk+1;
   end
end

//counter: count received data
initial begin
   cnt_data = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_data <= 0;
      else if(state==ST_RCVD && rx_vld) cnt_data <= cnt_data+1;
   end
end

//counter: count pause cycle
initial begin
   cnt_hold = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr || state==ST_RCVD) cnt_hold <= 0;
      else if(state==ST_HOLD) cnt_hold <= cnt_hold+1;
   end
end

//pause_cycle = pause_rate(random)*cfg_pause_cycle
initial begin
   pause_cycle = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_RCVD && rx_vld && rx_rdy && cfg_pause_en) pause_cycle <= {$random()} % cfg_pause_cycle;
   end
end

endmodule
