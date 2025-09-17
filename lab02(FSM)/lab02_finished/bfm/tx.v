module transmitter#(
parameter NAME = "transmitter",
parameter MEM_SIZE = 16,
parameter MSG_NUMB = 4
)(
output     [31:0] tx_data,
output            tx_vld,
input             tx_rdy,
output            tx_busy,
//new signal
output            start_p,
output     [63:0] msg_len,
output     [ 3:0] msg_be,
output            msg_lst,
input             dgst_done,

input             clk,
input             rst_n
);
//
//
////////////////////////////
//DECLARITION
////////////////////////////
//state
localparam ST_IDLE = 3'b000;
localparam ST_START = 3'b001;
localparam ST_W1 = 3'b010;
localparam ST_W2 = 3'b011;
localparam ST_W3 = 3'b100;
localparam ST_WDONE = 3'b101;
localparam ST_SEND = 3'b110;
localparam ST_HOLD = 3'b111;

reg [ 2:0] state;
reg [ 2:0] state_nx; 

//control
wire       clr;
wire[63:0] msg_word;
reg [31:0] cnt_w1;
reg [31:0] cnt_w2;
reg [31:0] cnt_w3;
reg [31:0] cnt_data;     //傳送到第幾個word了
reg [31:0] cnt_hold;
reg [63:0] cnt_msgword;   //傳到的那個message已經傳了幾個word了
reg [31:0] cnt_msg;      //傳送到第幾個message了

//setup configuration
reg [31:0] mem[0:MEM_SIZE-1];
reg [63:0] mem_msglen[0:MSG_NUMB-1];
reg [ 3:0] mem_msgbe[0:MEM_SIZE-1];
reg        mem_msglst[0:MEM_SIZE-1];
reg [31:0] cfg_length;            //test vector的word數量
reg        cfg_pause_en;          //pause enable (HOLD)
reg [31:0] cfg_pause_cycle;       //pause rate (range)
reg [31:0] pause_cycle;
reg        w2_en;
reg [31:0] w2_range;
reg [31:0] w2_cycle;
reg        w3_en;
reg [31:0] w3_range;
reg [31:0] w3_cycle;
reg        run_en;                //離開idle的signal
reg [31:0] w1_cycle;              //wait cycle

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

//load msg_len into mem_msglen
task load_msglen;
   input    [31:0]   addr;
   input    [63:0]   data;
   begin
      mem_msglen[addr] = data;
      $display($time,,"(%s) load msg_len = h%16h into memory[0x%8h]",NAME,data,addr);
   end
endtask

//load msg_be into mem_msgbe
task load_msgbe;
   input    [31:0]   addr;
   input    [ 3:0]   data;
   begin
      mem_msgbe[addr] = data;
      $display($time,,"(%s) load msg_be = h%1h into memory[0x%8h]",NAME,data,addr);
   end
endtask

//load msg_lst into mem_msglst
task load_msglst;
   input    [31:0]   addr;
   input             data;
   begin
      mem_msglst[addr] = data;
      $display($time,,"(%s) load msg_lst = h%1h into memory[0x%8h]",NAME,data,addr);
   end
endtask

//length(number) of data to be transmitted
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
      $display($time,,"(%s) setup hold_en = %1b",NAME,enable);
   end
endtask

//pause cycle: pause rate in a random range
task setcfg_pause_rate;
   input    [31:0]   clk_cycle;
   begin
      cfg_pause_cycle = clk_cycle;          //max pause(hold) cycle
      $display($time,,"(%s) setup hold_cycle = %3d",NAME,clk_cycle); //%3d
   end
endtask

//W2 enable: start_p之後要不要等一些cycle才進入SEND
task setcfg_w2_en;
   input             enable;
   begin
      w2_en = enable;
      $display($time,,"(%s) setup W2_en = %1b",NAME,enable);
   end
endtask

//W2 cycle: pause rate in a random range
task setcfg_w2_rate;
   input    [31:0]   clk_cycle;
   begin
      w2_range = clk_cycle;          //max pause(hold) cycle
      $display($time,,"(%s) setup w2_cycle = %3d",NAME,clk_cycle); //%3d
   end
endtask

//W3 enable: start_p之後要不要等一些cycle才進入SEND
task setcfg_w3_en;
   input             enable;
   begin
      w3_en = enable;
      $display($time,,"(%s) setup W3_en = %1b",NAME,enable);
   end
endtask

//W3 cycle: pause rate in a random range
task setcfg_w3_rate;
   input    [31:0]   clk_cycle;
   begin
      w3_range = clk_cycle;          //max pause(hold) cycle
      $display($time,,"(%s) setup w3_cycle = %3d",NAME,clk_cycle); //%3d
   end
endtask


//start=1, to trigger state machine to transmit data
task start;
   input    start_bit;
   input    [31:0]   cycle;
   begin
      @(posedge clk);
      run_en     <= start_bit;
      w1_cycle <= cycle;
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
assign tx_data = (tx_vld) ? mem[cnt_data] : 32'b0;
assign msg_be  = (tx_vld) ? mem_msgbe[cnt_data] : 4'b0;
assign msg_lst = (tx_vld) ? mem_msglst[cnt_data] : 1'b0;
assign start_p = state==ST_START;
assign msg_len = (start_p) ? mem_msglen[cnt_msg] : 64'b0;
assign msg_word = (mem_msglen[cnt_msg-1][4:0] == 0) ? (mem_msglen[cnt_msg-1] >> 5) : (mem_msglen[cnt_msg-1] >> 5) + 1; //這個msg有幾個word？
//assign msg_bit = (msg_be==4'h8) ? 32'd8 : (msg_be==4'hc) ? 32'd16 : (msg_be==4'he) ? 32'd24 : (msg_be==4'hf) ? 32'd32 : 32'd0;
//next state
always@*begin
   state_nx = state;
   case(state)
      ST_IDLE : if(run_en)
                 	if(w1_cycle==0)         state_nx = ST_START;
                    else                    state_nx = ST_W1;
      ST_W1   : if(cnt_w1==w1_cycle-32'h1)  state_nx = ST_START; 
	  ST_START: if(msg_len==0)              state_nx = ST_WDONE;
                else if(w2_en)              state_nx = ST_W2;
                else                        state_nx = ST_SEND;
      ST_W2   : if(cnt_w2==w2_cycle)        state_nx = ST_SEND;  
      ST_SEND : if(tx_rdy)
                  if(cnt_data == cfg_length - 32'b1)       state_nx = ST_IDLE;
                  else if(cnt_msgword == msg_word - 64'b1) state_nx = ST_WDONE;
                  else if(cfg_pause_en)                    state_nx = ST_HOLD;
      ST_HOLD : if(cnt_hold==pause_cycle)   state_nx = ST_SEND;
      ST_WDONE: if(dgst_done) begin 
                   if(w3_en)                state_nx = ST_W3;
				   else                     state_nx = ST_START;
			    end 
	  ST_W3   : if(cnt_w3==w3_cycle)        state_nx = ST_START;
      default : state_nx = state;
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
   w2_en           = 0;
   w2_range        = 0;
   w3_en           = 0;
   w3_range        = 0;
   run_en          = 0;
   w1_cycle        = 0;
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

//counter clear signal
assign clr = start_p;
//counter: count 第幾個message了
initial begin
   cnt_msg = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(start_p) cnt_msg <= cnt_msg+1;
   end
end

//counter: count 在這個message傳了幾個bit了
initial begin
   cnt_msgword = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_msgword <= 0;
	  if(state==ST_SEND && tx_rdy) cnt_msgword <= cnt_msgword + 1;
   end
end

//counter: count wait cycle
initial begin
   cnt_w1 = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_w1 <= 0;
      else if(state==ST_W1) cnt_w1 <= cnt_w1+1;
   end
end

//counter: count transmitted data
initial begin
   cnt_data = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk); 
      if(state==ST_SEND && tx_rdy) cnt_data <= cnt_data+1;
   end
end

//counter: count pause cycle
initial begin
   cnt_hold = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_SEND) cnt_hold <= 0;
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

//counter: count pause cycle between START and SEND
initial begin
   cnt_w2 = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_START) cnt_w2 <= 0;
      else if(state==ST_W2) cnt_w2 <= cnt_w2+1;
   end
end
//w2_cycle
initial begin
   w2_cycle = 0;

   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_START && w2_en) w2_cycle <= (($random % w2_range) + w2_range) % w2_range;
   end
end

//counter: count pause cycle between W_DONE and START
initial begin
   cnt_w3 = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_WDONE) cnt_w3 <= 0;
      else if(state==ST_W3) cnt_w3 <= cnt_w3+1;
   end
end
//w3_cycle
initial begin
   w3_cycle = 0;

   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(state==ST_START && w3_en) w3_cycle <= (($random % w3_range) + w3_range) % w3_range;
   end
end


endmodule
