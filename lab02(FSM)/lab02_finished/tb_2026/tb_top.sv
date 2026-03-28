`define INPUT_WORD_SIZE  32;
`define INPUT_WORD_NUMB  1220;
`define OUTPUT_WORD_SIZE 256;
`define OUTPUT_MSG_NUMB  30;
`define VALID_PAUSE_PROB 0;

module tb_top;
  
   //==============================
   // parameters
   //==============================
   localparam CLK_PERIOD = 20;
   localparam WORD_SIZE  = `INPUT_WORD_SIZE;
   localparam WORD_NUMB  = `INPUT_WORD_NUMB;
   localparam DGST_SIZE  = `OUTPUT_WORD_SIZE;
   localparam DGST_NUMB  = `OUTPUT_MSG_NUMB;
   localparam WIDTH_OF_LEN = 64;
   localparam WIDTH_OF_BE  = 4;
   localparam PROB       = `VALID_PAUSE_PROB;

   //==============================
   // signals
   //==============================
   wire                    start_p;
   wire                    msg_vld;
   wire                    msg_rdy;
   wire                    msg_lst;
   wire [WIDTH_OF_LEN-1:0] msg_len;
   reg  [WIDTH_OF_LEN-1:0] len;
   wire [WORD_SIZE   -1:0] msg_dat;
   wire [WIDTH_OF_BE -1:0] msg_be;


   
   wire                    dgst_done;
   wire [DGST_SIZE   -1:0] dgst;
   reg  [DGST_SIZE   -1:0] rd;

   reg                     rst_n;
   reg                     clk;
   
   integer                 time_out;
   integer                 pass_cnt;
   integer                 fail_cnt;
   integer                 i, j, k;

   //memory
   reg  [WORD_SIZE   -1:0] test_vec[0:WORD_NUMB-1];
   reg  [DGST_SIZE   -1:0] gold_vec[0:DGST_NUMB-1];
   reg  [WIDTH_OF_BE -1:0] msg_be_vec[0:WORD_NUMB-1];
   reg                     msg_lst_vec[0:WORD_NUMB-1];
   reg  [WIDTH_OF_LEN-1:0] msg_len_vec[0:DGST_NUMB-1];
   //==============================
   // test pattern
   //==============================
   `include "./test_include.v"

   //==============================
   // bfm
   //==============================
   transmitter#(
   .WIDTH_OF_LEN(WIDTH_OF_LEN),
   .WIDTH_OF_BE (WIDTH_OF_BE),
   .WORD_SIZE   (WORD_SIZE),
   .WORD_NUMB   (WORD_NUMB),
   .DGST_NUMB   (DGST_NUMB)
   )	TX 
   (
      .start_p       (start_p  ),
      .msg_len       (msg_len  ),
      .msg_vld       (msg_vld  ),
      .msg_dat       (msg_dat  ),
      .msg_be        (msg_be   ),
      .msg_lst       (msg_lst  ),
      .msg_rdy       (msg_rdy  ),
      .clk           (clk      ),                  
      .rst_n         (rst_n    )                  
   );

   receiver#(
   .DGST_SIZE   (DGST_SIZE)
   )	RX
   (
      .dgst_done     (dgst_done),
      .dgst          (dgst     ),
      .clk           (clk      ),                  
      .rst_n         (rst_n    )                  
   );

   checker#(
   .DGST_SIZE   (DGST_SIZE),
   .DGST_NUMB   (DGST_NUMB)
   )	CHKR
   (
      .clk           (clk      ),                  
      .rst_n         (rst_n    )                  
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
   end

   //==============================
   // clock
   //==============================
   initial begin
      clk = 0;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end


   //==============================
   // timeout
   //==============================
   initial begin
      if(!$value$plusargs("time_out=%d",time_out))begin
         time_out = 40_000;
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
         $fsdbDumpvars();
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
