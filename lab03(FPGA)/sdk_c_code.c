/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_io.h"       // 提供 Xil_Out32、Xil_In32 等 function
#include "xil_printf.h"   // 提供 xil_printf() 類似 printf 的功能
#include "xparameters.h"  // 包含 base address 定義（可選）
#include "xil_types.h"    // 包含 uint32_t、char8 等定義
#include "xuartlite_l.h"  // 提供 inbyte()

// IP Base Address：從 Address Editor 得知是 0x44A00000
#define BASE_ADDR     0x44A00000

// 記憶體映射的寄存器地址 (offset 來自 AXI IP 的對應）
#define REG0_ADDR     (BASE_ADDR + 0x00)  // slv_reg0：start/vld/len/lst
#define REG1_ADDR     (BASE_ADDR + 0x04)  // slv_reg1：byte enable
#define REG2_ADDR     (BASE_ADDR + 0x08)  // slv_reg2~9：data[0]~[7]
#define REG3_ADDR     (BASE_ADDR + 0x0C)
#define REG4_ADDR     (BASE_ADDR + 0x10)
#define REG5_ADDR     (BASE_ADDR + 0x14)
#define REG6_ADDR     (BASE_ADDR + 0x18)
#define REG7_ADDR     (BASE_ADDR + 0x1C)
#define REG8_ADDR     (BASE_ADDR + 0x20)
#define REG9_ADDR     (BASE_ADDR + 0x24)

#define BACK_ADDR     (BASE_ADDR + 0x28)  // dgst_vld/clear
#define RESULT_BASE   (BASE_ADDR + 0x2C)  // result_0 ~ result_7：digest 結果

void print_binary_8(u8 value) {
    for (int i = 7; i >= 0; i--) {
        xil_printf("%c", (value & (1 << i)) ? '1' : '0');
        if (i % 4 == 0) xil_printf(" ");  // 每 4 位空一格方便閱讀
    }
    xil_printf("\n\r");
}
void print_binary_32(u32 value) {
    for (int i = 31; i >= 0; i--) {
        xil_printf("%c", (value & (1 << i)) ? '1' : '0');
        if (i % 4 == 0) xil_printf(" ");  // 每 4 位空一格方便閱讀
    }
    xil_printf("\n\r");
}

int main() {

    init_platform();

    char msg[33];      // 儲存使用者輸入的最多 32 個字元（+1 為字串結尾符號 '\0'）
    u32 data[8];       // 每 4 byte 為一組，共 8 組 word
    u32 be = 0;        // 32-bit 的 byte enable
    u8  last_mask = 0; // 最後一個 word 的 mask
    int len = 0;       // 字串實際長度（輸入的byte數）
    int i;

    while (1) {
        // 提示使用者輸入字串
        xil_printf("Message: ");

        for (i = 0; i < 32; i++) msg[i] = 0;

        // 使用 inbyte() 收集字元直到使用者按 Enter（'\r'）或輸入達 32 個字元
        len = 0;
        char c = inbyte();
        while (c != '\r' && len < 32) {
            msg[len++] = c;
            xil_printf("%c", c);  // echo 輸入字元
            c = inbyte();
        }
        msg[len] = '\0'; // 字串結尾補 '\0'

        xil_printf("\n\r");  // 換行

        //for (int i = 0; i < 33; i++) {
        //    xil_printf("msg[%d] = %c (0x%02X)\n\r", i, msg[i], msg[i]);
        //}  //確認有正確輸入進來

        // 初始化 data[] 內容為 0
        for (i = 0; i < 8; i++) data[i] = 0;

        // 把輸入的字串塞進 data[0~7]（每 4 byte 為一個 32-bit word）
        for (i = 0; i < 32; i++) {
            int word_index = i / 4;
            int byte_index = i % 4;
            data[word_index] |= ((u32)msg[i]) << (8 * (3 - byte_index));
        //    xil_printf("data[%d] = 0x%08X\n\r", word_index, data[word_index]);
        }


        // 計算每個 word 對應的 byte enable
        be = 0;
        for (i = 0; i < (len + 3) / 4; i++) {
            int valid_byte = 4;
            if (i == (len / 4)) valid_byte = len % 4;
            if (valid_byte == 0 && len > 0) valid_byte = 4;

            u8 be_i = (0xF << (4 - valid_byte)) & 0xF;
            be |= ((u32)be_i) << (i * 4);
        //    xil_printf("be = 0x%08X\n\r", be);
        }


        // 計算哪個是最後一個 word（用 mask）
        last_mask = 1 << ((len + 3) / 4 - 1);
        //xil_printf("lst = ");
        //print_binary_8(last_mask);

        // 將 data[] 寫入 slv_reg2 ~ slv_reg9
        Xil_Out32(REG2_ADDR, data[0]);
        Xil_Out32(REG3_ADDR, data[1]);
        Xil_Out32(REG4_ADDR, data[2]);
        Xil_Out32(REG5_ADDR, data[3]);
        Xil_Out32(REG6_ADDR, data[4]);
        Xil_Out32(REG7_ADDR, data[5]);
        Xil_Out32(REG8_ADDR, data[6]);
        Xil_Out32(REG9_ADDR, data[7]);

        // 寫入 byte enable 到 slv_reg1
        Xil_Out32(REG1_ADDR, be);

        // 組出 slv_reg0 的控制訊號：
        // [7:2] = 長度 (byte)
        // [15:8] = last word mask
        // [0] = start flag
        u32 reg0 = 0;
        reg0 |= (len << 2);           // bits[7:2]：輸入長度（byte）
        reg0 |= (1 << 0);             // bit[0]：start = 1
        reg0 |= (last_mask << 8);     // bits[15:8]：last word

        Xil_Out32(REG0_ADDR, reg0);   // 寫入 start
        //xil_printf("reg0 = ");
        //print_binary_32(reg0);
        // 再補上 valid flag（bit[1]）
        reg0 |= (1 << 1);
        Xil_Out32(REG0_ADDR, reg0);
        //xil_printf("reg0 = ");
        //print_binary_32(reg0);
        //u32 temp = Xil_In32(REG0_ADDR);
        //xil_printf("inside_reg0 = ");
        //print_binary_32(temp);


        while (!(Xil_In32(BACK_ADDR) & (1 << 30)));
        reg0 &= ~((1 << 0) | (1 << 1));              // 清除 start 和 valid bit
        Xil_Out32(REG0_ADDR, reg0);
        //xil_printf("reg0 = ");
        //print_binary_32(reg0);
        // 等待 SHA256 模組處理完成（等待 dgst_vld[31] = 1）
        //xil_printf("Waiting for dgst_vld...\n\r");
        while (!(Xil_In32(BACK_ADDR) & (1 << 31)));
        //xil_printf("Got digest!\n\r");

        // 印出 Digest 結果（256-bit, 共 8 個 word）
        xil_printf("Digest:\n\r");
        for (i = 7; i >= 0; i--) {
            u32 val = Xil_In32(RESULT_BASE + i * 4);
            xil_printf("%08X", val);
            if (i == 4) xil_printf("\n\r");  // 4 字後換行
        }
        xil_printf("\n\r");
    }
    cleanup_platform();
    return 0;
}

