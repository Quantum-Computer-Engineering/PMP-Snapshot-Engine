`timescale 1ns/1ps

module tb;

///////////////////////////////////////////////////
////////////// INTERNAL SIGNALS ///////////////////
///////////////////////////////////////////////////
reg tb_clk;
reg tb_reset;

/////////// ////////////////////////////////////////
initial 
begin       
    tb_clk = 1'b0;
end

always #10 tb_clk = ~tb_clk;

reg [31:0] read_data;

initial
    begin
    
        $display ("running the tb");
        
        tb_reset = 1'b0;
        #100
        tb_reset = 1'b1;
        
        #20000
        tb_reset = 1'b1;
                

    end

E40S_with_Caches_wrapper CV32E40S_SoC_with_Caches
		(
				.sysclk_p(tb_clk),
				.sysclk_n(~tb_clk),
				.sys_reset(tb_reset), // In this case it is controlled by the VIO logic
			    .OUTPUT_LEDs(    ),
			    .RsTx(   )
		);


endmodule
