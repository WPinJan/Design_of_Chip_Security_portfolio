module transmitter#(
parameter NAME = "transmitter",
parameter MEM_SIZE = 16
)(
output     [31:0] tx_data,
output            tx_vld,
input             tx_rdy,
output            tx_busy,

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
localparam ST_SEND = 2'b10;
localparam ST_HOLD = 2'b11;

reg [ 1:0] state;
reg [ 1:0] state_nx; 

//control
wire       clr;
reg [31:0] cnt_clk;
reg [31:0] cnt_data;
reg [31:0] cnt_hold;

//setup configuration
reg [31:0] mem[0:MEM_SIZE-1];
reg [31:0] cfg_length;         // test vector length
reg        cfg_pause_en;       //pause enable
reg [31:0] cfg_pause_cycle;    //pause rate
reg [31:0] pause_cycle;

reg        run_en;
reg [31:0] wait_cycle;         //initial wait cycle

integer    i;

////////////////////////////
//TASK: SETUP CONFIGURATION
////////////////////////////
//load test vectors into memory
task loadmem;
   input    [31:0]   addr;
   input    [31:0]   data;
   begin
      mem[addr] = data;
      $display($time,,"(%s) load data = h%8h into memory[0x%8h]",NAME,data,addr);
   end
endtask

//length of transmitted data
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
      cfg_pause_cycle = clk_cycle;          //max pause(hold) cycle
      $display($time,,"(%s) setup cfg_pause_cycle = %3d",NAME,clk_cycle); //%3d
   end
endtask

//start=1, to trigger state machine to transmit data
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
assign tx_busy = state!=ST_IDLE;
assign tx_vld  = state==ST_SEND;
assign tx_data = mem[cnt_data];
//next state
always@*begin
   state_nx = state;

   case(state)
      ST_IDLE: if(run_en) 
                  if(wait_cycle==0)              state_nx = ST_SEND;
                  else                           state_nx = ST_WAIT;
      ST_WAIT: if(cnt_clk==wait_cycle-32'h1)     state_nx = ST_SEND;      
      ST_SEND: if(tx_rdy)
                  if(cnt_data==cfg_length-32'h1) state_nx = ST_IDLE;
                  else if(cfg_pause_en)          state_nx = ST_HOLD;
      ST_HOLD: if(cnt_hold==pause_cycle)         state_nx = ST_SEND;
   endcase
end

////////////////////////////
//Initial
////////////////////////////
//default value
initial begin
   for(i=0; i<MEM_SIZE; i=i+1)begin
      mem[i] = 0;
   end

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
      @(posedge clk);          // =forever
      state <= state_nx;
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
//counter: count transmitted data
initial begin
   cnt_data = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_data <= 0;
      else if(state==ST_SEND && tx_rdy) cnt_data <= cnt_data+1;
   end
end
//counter: count pause cycle
initial begin
   cnt_hold = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr || state==ST_SEND) cnt_hold <= 0;
      else if(state==ST_HOLD) cnt_hold <= cnt_hold+1;
   end
end
//pause_cycle = pause_rate(random)*cfg_pause_cycle
initial begin
   pause_cycle = 0;

   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_SEND && tx_vld && tx_rdy && cfg_pause_en) pause_cycle <= (($random % cfg_pause_cycle) + cfg_pause_cycle) % cfg_pause_cycle;
   end
end
//always @(posedge clk) begin
//  if (cnt_data < cfg_length)
//    $display($time,, "Monitor TX: cnt_data = %0d, mem[cnt_data] = %h", cnt_data, mem[cnt_data]);
//end

endmodule
