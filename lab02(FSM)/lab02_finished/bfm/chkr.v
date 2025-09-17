module checker#(
parameter NAME = "checker",
parameter MEM_SIZE = 100,
parameter WORD_LEN = 256
)(
input [ WORD_LEN-1:0] rx_data,
input                 dgst_vld,
input                 dgst_done,

input                 clk,
input                 rst_n
);
//
//
////////////////////////////
//DECLARITION
////////////////////////////
//state
localparam ST_IDLE = 1'b0;
localparam ST_CHKR = 1'b1;

reg         state;
reg         state_next; 

//control
wire        clr;
reg  [31:0] cnt_clk;
reg  [31:0] cnt_data;
wire        cnt_ps_en;
reg  [31:0] cnt_ps;      //verify data correctness: pass counter
wire        cnt_fl_en;
reg  [31:0] cnt_fl;      //verify data correctness: fail counter
//fail case
integer     i;
wire        cmp_neq;     //compare not equal
reg         flg_x;       //flag for x-state
wire        flg_ovfl;
wire        fail;    
wire        remain_fail; //fail to remain the output between done and start
//setup configuration
reg  [ WORD_LEN-1:0] mem[0:MEM_SIZE-1];
wire [ WORD_LEN-1:0] chk_data;
reg  [31:0] cfg_length;
reg         cfg_chk_x_en;
reg         cfg_chk_ovfl_en;
reg         cfg_ps_shwmsg_en;
reg         cfg_fl_hltsim_en;

reg         run_en;

////////////////////////////
//TASK: SETUP CONFIGURATION
////////////////////////////
//load golden vectors into memory
task loadmem;
   input    [31:0]   addr;
   input    [WORD_LEN-1:0]   data;
   begin
      mem[addr] = data;
      $display($time,,"(%s) load data = h%2h into memory[0x%8h]",NAME,data,addr);
   end
endtask

//length of checked data
task setcfg_length;
   input    [31:0]   length;
   begin
      cfg_length = length;
      $display($time,,"(%s) setup cfg_length = %1d",NAME,length);
   end
endtask

//check data value if unknown?
task setcfg_check_unknown;
   input             enable;
   begin
      cfg_chk_x_en = enable;
      $display($time,,"(%s) setup cfg_chk_x_en = %1b",NAME,enable);
   end
endtask

//check data length if overflow?
task setcfg_check_overflow;
   input             enable;
   begin
      cfg_chk_ovfl_en = enable;
      $display($time,,"(%s) setup cfg_chk_ovfl_en = %1b",NAME,enable);
   end
endtask

//display passed message
task setcfg_pass_showmsg;
   input             enable;
   begin
      cfg_ps_shwmsg_en = enable;
      $display($time,,"(%s) setup cfg_ps_shwmsg_en = %1b",NAME,enable);
   end
endtask

//fail case to stop simulation
task setcfg_fail_stopsim;
   input             enable;
   begin
      cfg_fl_hltsim_en = enable;
      $display($time,,"(%s) setup cfg_fl_hltsim_en = %1b",NAME,enable);
   end
endtask

//return pass count
task get_pass_cnt;
   output reg [31:0] ps_cnt;
   begin
      ps_cnt = cnt_ps;
      $display($time,,"(%s) get back cnt_ps = %1d",NAME,cnt_ps);
   end
endtask

//return fail count
task get_fail_cnt;
   output reg [31:0] fl_cnt;
   begin
      fl_cnt = cnt_fl;
      $display($time,,"(%s) get back cnt_fl = %1d",NAME,cnt_fl);
   end
endtask

//start=1, to trigger state machine to check data
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
//checker signals
assign chk_data = mem[cnt_data];

//fail case
assign cmp_neq = dgst_done && rx_data!==chk_data;
assign remain_fail = (cmp_neq==0) && dgst_vld && rx_data!==mem[cnt_data-1];
assign flg_x = cfg_chk_x_en && (dgst_vld || dgst_done) && rx_data === 32'hxxxxxxxx;
assign flg_ovfl = cfg_chk_ovfl_en && cnt_data > cfg_length;
assign fail = cmp_neq || flg_x || flg_ovfl || remain_fail;

//next state
always@*begin
   state_next = state;

   case(state)
      ST_IDLE: if(run_en)                    state_next = ST_CHKR;     
      ST_CHKR: if(cnt_data==cfg_length)      state_next = ST_IDLE;
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
   cfg_length       = 0;
   cfg_chk_x_en     = 0;
   cfg_chk_ovfl_en  = 0;
   cfg_ps_shwmsg_en = 0;
   cfg_fl_hltsim_en = 0;

   run_en           = 0;

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
      else if(dgst_done) cnt_data <= cnt_data+1;
   end
end

//counter: count passed data
//
assign cnt_ps_en  = ( dgst_done||dgst_vld ) && rx_data===chk_data && ~fail;
//
initial begin
   cnt_ps = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_ps <= 0;
      else if(cnt_ps_en)begin
         cnt_ps <= cnt_ps+1;
         //display
         if(cfg_ps_shwmsg_en) $display($time,,"PASS) RX_DATA[0x%8h] (%s)",cnt_data,NAME);//shown pass message
      end
   end
end

//counter: count failed data
//
assign cnt_fl_en  = ( dgst_done||dgst_vld ) && fail;
//
initial begin
   cnt_fl = 0;
   @(posedge rst_n);
   while(1)begin
      @(posedge clk);
      if(clr) cnt_fl <= 0;
      else if(cnt_fl_en)begin
         cnt_fl <= cnt_fl+1;
         //display
         if(cmp_neq)          $display($time,,"NEQ) RX_DATA[0x%8h] = %2h, GOLD_DATA[0x%8h] = %2h (%s)",cnt_data,rx_data,cnt_data,mem[cnt_data],NAME);
         if(flg_x)            $display($time,,"UNKNOWN) RX_DATA[0x%8h] (%s)",cnt_data,NAME);//check unknown data
         if(flg_ovfl)         $display($time,,"OVERFLOW) (%s)",NAME);//check data length is overflow
         if(remain_fail)      $display($time,,"REMAIN_FAIL) RX_DATA[0x%8h] = %2h, GOLD_DATA[0x%8h] = %2h (%s)",cnt_data,rx_data,cnt_data,mem[cnt_data],NAME);
		 //Fail to halt simulation
         if(cfg_fl_hltsim_en)begin
            $display($time,,"FAIL) stop simultion (%s)",NAME);
            $finish;//check fail case, and finish simulation
         end
      end
   end
end

endmodule
