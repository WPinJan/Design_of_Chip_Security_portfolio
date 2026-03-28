initial begin
	if($test$plusargs("testcase_1")) begin
		test_begin;
		//read vectors from .dat
       	$readmemh("../bfm/test_case/all_vectors/test_vec.dat",test_vec);
       	$readmemh("../bfm/test_case/all_vectors/gold_vec.dat",gold_vec);
       	$readmemh("../bfm/test_case/all_vectors/msg_len.dat",msg_len_vec);
       	$readmemh("../bfm/test_case/all_vectors/msg_be.dat",msg_be_vec);
       	$readmemh("../bfm/test_case/all_vectors/msg_lst.dat",msg_lst_vec);
       	//load vectors into memory
       	for(int i=0;i<WORD_NUMB;i=i+1) TX.load_test_dat(i,test_vec[i]);
       	for(int i=0;i<DGST_NUMB;i=i+1) CHKR.load_exp_dat(i,gold_vec[i]);
       	for(int i=0;i<WORD_NUMB;i=i+1) TX.load_msg_be(i,msg_be_vec[i]);
       	for(int i=0;i<WORD_NUMB;i=i+1) TX.load_msg_lst(i,msg_lst_vec[i]);
       	for(int i=0;i<DGST_NUMB;i=i+1) TX.load_msg_len(i,msg_len_vec[i]);
  
      	for(i = 1; i <= DGST_NUMB ; i = i+1)begin
			$display($time,,"==================  MESSAGE %1d  ==================", i);
		 	TX.start(i);
			TX.get_len(i, len);
		 	if (len == 64'h0)
			 	@(posedge clk);
		 	else begin
				j = 0;
				TX.first_write(i, j);
				if(msg_lst_vec[j] != 1) begin
					while(msg_lst_vec[j+1] != 1) begin
						TX.handshake_and_write(j+1,PROB);
						j = j + 1;
					end
					TX.handshake_and_write(j+1,PROB);
				end
				TX.end_writing;
			end
         	RX.read_at_done(rd);
         	CHKR.compare(i, rd);
      	end
		CHKR.get_pass_cnt(pass_cnt);
		CHKR.get_fail_cnt(fail_cnt);
      	test_report;
		test_end;
   	end
   
end
