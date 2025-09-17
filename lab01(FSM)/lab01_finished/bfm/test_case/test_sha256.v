//This is test_case
initial begin
   if($test$plusargs("test_sha256")) begin
	   @(ev_rst_done);
	   //read vectors from .dat
       $readmemh("../bfm/test_case/test_vec.dat",test_vec);
       $readmemh("../bfm/test_case/gold_vec.dat",gold_vec);
       //load test vectors into memory
       for(int i=0;i<TX_TESTLEN;i=i+1) TX.loadmem(i,test_vec[i]);
       //load golden vectors into memory
       for(int i=0;i<RX_TESTLEN;i=i+1) CHKR.loadmem(i,gold_vec[i]);

       //config: TX data are always valid, RX data are valid in a while (depend on pause rate)
       TX.setcfg_length(TX_TESTLEN);    //setup 傳了多少test vector之後關閉(=>idle)
       TX.setcfg_pause(1);                //setup 要不要有hold state(valid = 0)
       TX.setcfg_pause_rate(100);          //setup 要hold多少個cycle的最大值

       RX.setcfg_length(RX_TESTLEN);
       RX.setcfg_pause(1);
       RX.setcfg_pause_rate(70);

       CHKR.setcfg_length(RX_TESTLEN);
       CHKR.setcfg_check_unknown(1);
       CHKR.setcfg_check_overflow(1);
       CHKR.setcfg_pass_showmsg(1);//fail msg is always shown
       CHKR.setcfg_fail_stopsim(1);//fail then call $finish

       //start the test
       fork
          TX.start(1,100);//delay 100 cycle then start bfm
          RX.start(1,10);
          CHKR.start(1,10);
       join

       //wait done
       @(posedge clk);
       while (tx_busy | rx_busy)begin//check bfm busy status
          @(posedge clk);
       end 
      
       ->ev_test_done;
                  

   end
end


