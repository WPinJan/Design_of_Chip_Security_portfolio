`define TX_TESTLENGTH 32000
`define RX_TESTLENGTH 128000


module tb_top;
  
   //==============================
   // parameters
   //==============================
   localparam CLK_PERIOD = 20;
   localparam TX_TESTLEN = `TX_TESTLENGTH;
   localparam RX_TESTLEN = `RX_TESTLENGTH;



   //==============================
   // signals
   //==============================
   reg  [31:0] test_vec[0:TX_TESTLEN-1];
   reg  [31:0] gold_vec[0:RX_TESTLEN-1];

   wire [31:0] tx_data;
   wire        tx_vld;
   wire        tx_rdy;
   wire        tx_busy;
   wire [31:0] rx_data;
   wire        rx_vld;
   wire        rx_rdy;
   wire        rx_busy;

   reg  [31:0] pass_cnt;
   reg  [31:0] fail_cnt;

   event       ev_rst_done;
   event       ev_test_done;

   integer     time_out;    //universal?
//   integer     i;
   reg         rst_n;
   reg         clk;

   
   //==============================
   // test pattern (test case)
   //==============================
   `include "../bfm/test_case/test_include.v"

   //==============================
   // bfm
   //==============================
   transmitter#(
      .MEM_SIZE   (TX_TESTLEN)
   )  TX
   (
      .tx_data    (tx_data),
      .tx_vld     (tx_vld),
      .tx_rdy     (tx_rdy),
      .tx_busy    (tx_busy),
   
      .clk        (clk),
      .rst_n      (rst_n)
   );
   
   reciever       RX
   (
      .rx_data    (rx_data),
      .rx_vld     (rx_vld),
      .rx_rdy     (rx_rdy),
      .rx_busy    (rx_busy),
   
      .clk        (clk),
      .rst_n      (rst_n)
   );
   
   checker#(
      .MEM_SIZE   (RX_TESTLEN)
   )  CHKR
   (
      .rx_data    (rx_data),
      .rx_vld     (rx_vld),
      .rx_rdy     (rx_rdy),
   
      .clk        (clk),
      .rst_n      (rst_n)
   );



   //==============================
   // dut
   //==============================
   sha2_msg      SHA2_MSG
   (
      //from/to TX
      .msg_vld    (tx_vld ),
      .msg_dat    (tx_data ),
      .msg_rdy    (tx_rdy ),
      //from/to RX
      .word_vld   (rx_vld),
      .word       (rx_data),
      .word_rdy   (rx_rdy),
   
      .clk        (clk     ),
      .rst_n      (rst_n   )
   );


   //==============================
   // reset只有一開始嗎？
   //==============================
   initial begin
      #0;
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
