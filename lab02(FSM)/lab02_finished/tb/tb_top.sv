`define TX_TESTLENGTH 1203
`define RX_TESTLENGTH 23
`define TX_MSG_NUMBER 23

module tb_top;
  
   //==============================
   // parameters
   //==============================
   localparam CLK_PERIOD = 20;
   localparam TX_TESTLEN = `TX_TESTLENGTH;
   localparam RX_TESTLEN = `RX_TESTLENGTH;
   localparam TX_MSG_NUMB = `TX_MSG_NUMBER;


   //==============================
   // signals
   //==============================
   reg  [   31:0] test_vec[0:TX_TESTLEN-1];
   reg  [  255:0] gold_vec[0:RX_TESTLEN-1];
   reg  [   31:0] msg_be_vec[0:TX_TESTLEN-1];
   reg            msg_lst_vec[0:TX_TESTLEN-1];
   reg  [   63:0] msg_len_vec[0:TX_MSG_NUMB-1];

   wire           tx_busy;
   wire           rx_busy;

   wire           start_p;
   wire [ 64-1:0] msg_len;
   wire           msg_vld;
   wire [ 32-1:0] msg_dat;
   wire [  4-1:0] msg_be;
   wire           msg_lst;
   wire           msg_rdy;
   
   wire           dgst_done;
   wire [256-1:0] dgst;

   wire           dgst_vld;  //在rx外加的

   reg  [   31:0] pass_cnt;
   reg  [   31:0] fail_cnt;

   event          ev_rst_done;
   event          ev_test_done;

   reg            rst_n;
   reg            clk;
   
   integer        time_out;
   

   
   //==============================
   // test pattern (test case)
   //==============================
   `include "../bfm/test_case/test_include.v"

   //==============================
   // bfm
   //==============================
   transmitter#(
      .MEM_SIZE   (TX_TESTLEN),
	  .MSG_NUMB   (TX_MSG_NUMB)
   )  TX
   (
      .tx_data    (msg_dat),
      .tx_vld     (msg_vld),
      .tx_rdy     (msg_rdy),
      .tx_busy    (tx_busy),
	  //new signal
	  .start_p    (start_p  ),
	  .msg_len    (msg_len  ),
      .msg_be     (msg_be   ),
      .msg_lst    (msg_lst  ),
	  .dgst_done  (dgst_done),

      .clk        (clk),
      .rst_n      (rst_n)
   );
   
   reciever       RX
   (
      .rx_data    (dgst),
      .rx_busy    (rx_busy),
      //new signal
      .dgst_done  (dgst_done),
	  .start_p    (start_p),
	  .dgst_vld   (dgst_vld),
      .clk        (clk),
      .rst_n      (rst_n)
   );
   
   checker#(
      .MEM_SIZE   (RX_TESTLEN)
   )  CHKR
   (
      .rx_data    (dgst),
      .dgst_vld   (dgst_vld),
      .dgst_done  (dgst_done),

      .clk        (clk),
      .rst_n      (rst_n)
   );



   //==============================
   // dut
   //==============================
   sha2              I_SHA2
   (
      //from/to TX
      .start_p       (start_p  ),
      .msg_len       (msg_len  ),
      .msg_vld       (msg_vld  ),
      .msg_dat       (msg_dat  ),
      .msg_be        (msg_be   ),
      .msg_lst       (msg_lst  ),
      .msg_rdy       (msg_rdy  ),
      //from/to RX
      .dgst_done     (dgst_done),
      .dgst          (dgst     ),
      .clk           (clk      ),
      .rst_n         (rst_n    )
   );
   //==============================
   // reset
   //==============================
   initial begin
      #100;
      rst_n = 0;
      #10;
      rst_n = 1;
	  ->ev_rst_done;
   end

   //==============================
   // clock
   //==============================
   initial begin
      clk = 0;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end

   //==============================
   // Report test
   //==============================
   initial begin
      @(ev_test_done);
      
      //get the result
      CHKR.get_pass_cnt(pass_cnt);
      CHKR.get_fail_cnt(fail_cnt);
      //
      $display($time,,"===========================");
      $display($time,,"  cnt_pass = h%8h", pass_cnt);
      $display($time,,"  cnt_fail = h%8h", fail_cnt);
      $display($time,,"===========================");
      //
      if(fail_cnt==0 && pass_cnt==RX_TESTLEN) begin
         $display($time,,"TEST is PASSED");
         $display($time,,"===========================");
      end
      else begin
         $display($time,,"TEST is FAILED");
         $display($time,,"===========================");
      end
      //
      #100;
      $finish;
   end 



   //==============================
   // timeout
   //==============================
   initial begin
      if(!$value$plusargs("time_out=%d",time_out))begin        //注意有!
         time_out = 400000;
      end
      repeat(time_out)begin
         #(1_000);//1us
      end
      $display($time,,"FAIL, timeout...");
      $finish;
   end
   
   
   //==============================
   // dump
   //==============================
   initial begin
   `ifdef USE_FSDB
      if($test$plusargs("FSDB"))begin
         $fsdbDumpfile("wave.fsdb");
         $fsdbDumpvars(0, tb_top, "+all");
      end
   `endif   
   `ifdef USE_VCD
      if($test$plusargs("VCD"))begin
         $dumpfile("wave.vcd");
         $dumpvars();
         //only dump one hierarchy from tb_top
         //$dumpvars(1,tb_top);
         //$dumpvars(1,tb_top.I_SHA2_MSG);
      end
   `endif   
   end

endmodule
