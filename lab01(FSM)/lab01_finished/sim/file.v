//time scale
`timescale 1ns/1ps

//tb_top
`include "../tb/tb_top.sv"

//bfm
`include "../bfm/tx.v"
`include "../bfm/rx.v"
`include "../bfm/chkr.v"

//dut
`include "../rtl/dut_include.v"
