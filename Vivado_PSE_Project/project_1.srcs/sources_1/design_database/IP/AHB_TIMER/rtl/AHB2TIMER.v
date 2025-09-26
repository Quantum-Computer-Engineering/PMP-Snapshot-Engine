//////////////////////////////////////////////////////////////////////////////////
//END USER LICENCE AGREEMENT                                                    //
//                                                                              //
//Copyright (c) 2012, ARM All rights reserved.                                  //
//                                                                              //
//THIS END USER LICENCE AGREEMENT (�LICENCE�) IS A LEGAL AGREEMENT BETWEEN      //
//YOU AND ARM LIMITED ("ARM") FOR THE USE OF THE SOFTWARE EXAMPLE ACCOMPANYING  //
//THIS LICENCE. ARM IS ONLY WILLING TO LICENSE THE SOFTWARE EXAMPLE TO YOU ON   //
//CONDITION THAT YOU ACCEPT ALL OF THE TERMS IN THIS LICENCE. BY INSTALLING OR  //
//OTHERWISE USING OR COPYING THE SOFTWARE EXAMPLE YOU INDICATE THAT YOU AGREE   //
//TO BE BOUND BY ALL OF THE TERMS OF THIS LICENCE. IF YOU DO NOT AGREE TO THE   //
//TERMS OF THIS LICENCE, ARM IS UNWILLING TO LICENSE THE SOFTWARE EXAMPLE TO    //
//YOU AND YOU MAY NOT INSTALL, USE OR COPY THE SOFTWARE EXAMPLE.                //
//                                                                              //
//ARM hereby grants to you, subject to the terms and conditions of this Licence,//
//a non-exclusive, worldwide, non-transferable, copyright licence only to       //
//redistribute and use in source and binary forms, with or without modification,//
//for academic purposes provided the following conditions are met:              //
//a) Redistributions of source code must retain the above copyright notice, this//
//list of conditions and the following disclaimer.                              //
//b) Redistributions in binary form must reproduce the above copyright notice,  //
//this list of conditions and the following disclaimer in the documentation     //
//and/or other materials provided with the distribution.                        //
//                                                                              //
//THIS SOFTWARE EXAMPLE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS" AND ARM     //
//EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING     //
//WITHOUT LIMITATION WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR //
//PURPOSE, WITH RESPECT TO THIS SOFTWARE EXAMPLE. IN NO EVENT SHALL ARM BE LIABLE/
//FOR ANY DIRECT, INDIRECT, INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY/
//KIND WHATSOEVER WITH RESPECT TO THE SOFTWARE EXAMPLE. ARM SHALL NOT BE LIABLE //
//FOR ANY CLAIMS, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, //
//TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE    //
//EXAMPLE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE EXAMPLE. FOR THE AVOIDANCE/
// OF DOUBT, NO PATENT LICENSES ARE BEING LICENSED UNDER THIS LICENSE AGREEMENT.//
//////////////////////////////////////////////////////////////////////////////////


module AHB2TIMER
(
  //Inputs
  input wire HCLK,
  input wire HRESETn,
  input wire [31:0] HADDR,
  input wire [31:0] HWDATA,
  input wire [1:0] HTRANS,
  input wire HWRITE,
  input wire HSEL,
  input wire HREADY,
  
	//Output
  output wire [31:0] HRDATA,
  output wire HREADYOUT,
  output timer_irq_o
);
    
    // mtimecmp: Holds compare value for the timer
    localparam [15:0] MTIMECMP_OFFSET = 32'h4000;  
    
    // mtime: Provides the current timer value
    localparam [15:0] MTIME_OFFSET = 32'hBFF8;  
  
    reg [63:0] mtimecmp;
    reg [63:0] mtime;
    
    //AHB Registers
    reg last_HWRITE;
    reg [31:0] last_HADDR;
    reg last_HSEL;
    reg [1:0] last_HTRANS;
      
    assign HREADYOUT = 1'b1; //Always ready

    always @(posedge HCLK)
    begin
        if(HREADY)
        begin
            last_HWRITE <= HWRITE;
            last_HSEL <= HSEL;
            last_HADDR <= HADDR;
            last_HTRANS <= HTRANS;
        end
    end           


    always @(posedge HCLK, negedge HRESETn)
    begin
        if(!HRESETn) 
        begin
            mtimecmp    <= 64'h0;
            mtime       <= 64'h0;
        end 
        else 
        begin
            // Increment every clock cycle
            mtime <= mtime + 1;
            
            /* Check for write attempts. */
            if (last_HWRITE & last_HSEL & last_HTRANS[1]) 
            begin
                /* Lower half of mtimecmp */
                if (last_HADDR[15:0] == MTIMECMP_OFFSET) 
                begin
                    mtimecmp[31:0] <= HWDATA;
                end 
                /* Upper half of mtimecmp */
                else if (last_HADDR[15:0] == (MTIMECMP_OFFSET + 4)) 
                begin
                    mtimecmp[63:32] <= HWDATA;
                end 
                /* Lower half of mtime */
                else if (last_HADDR[15:0] == MTIME_OFFSET) 
                begin
                    mtime[31:0] <= HWDATA;
                end 
                /* Upper half of mtime */
                else if (last_HADDR[15:0] == (MTIME_OFFSET + 4)) 
                begin
                    mtime[63:32] <= HWDATA;
                end
            end
        end
    end
        

    /* Trigger interrupt if mtime exceeds cmp reg. */
    // TODO: It should be mtime > mtimecmp but with that
    // the irq signal stays high, which make the the cpu
    // put the wrong return address into mepc.
    // It puts the vector table address instead of the address
    // during the interrupt.
    assign timer_irq_o = mtime > mtimecmp;
    
    
    assign HRDATA = (last_HADDR[15:0] == MTIMECMP_OFFSET) ? mtimecmp[31:0] :
                    (last_HADDR[15:0] == (MTIMECMP_OFFSET + 4)) ? mtimecmp[63:32] :
                    (last_HADDR[15:0] == MTIME_OFFSET) ? mtime :
                    (last_HADDR[15:0] == (MTIME_OFFSET + 4)) ? mtimecmp[63:32] :
                    32'h0000_0000;
            


endmodule
