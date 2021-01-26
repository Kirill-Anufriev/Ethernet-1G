`timescale 1ns / 1ps
/*
ћодуль приема и согласовани€ по частоте данных от UDP
*/
/*
UDP_DATA_MODULE 
#(
.DATA_WIDTH (72)
)
UDP_DATA_MODULE
(
.RST            (),

.DATA_I_CLK     (),
.DATA_I         (),
.DATA_I_VLD     (),

.DATA_O_CLK     (),
.DATA_O_VLD     (),
.DATA_O         ()
);
*/

module UDP_DATA_MODULE
#(
parameter DATA_WIDTH = 72
)
(
input RST,
input DATA_I_CLK,
input [DATA_WIDTH - 1:0] DATA_I,
input DATA_I_VLD,

input      DATA_O_CLK,
output reg DATA_O_VLD,
output [DATA_WIDTH - 1:0]  DATA_O
);
localparam IDLE_ST      = 2'b00,
           WAIT_VLD_ST  = 2'b01, 
           WAIT_RD_ST   = 2'b10;


reg DATA_O_RDEN;
reg [1:0] ST; 

wire EMPTY;
wire DATA_O_VALID;

/*
PULSE2PULSE // —огласование сигналов по частоте
#(  
.CLOCK_RELATIONSHIP (2)
)
PULSE2PULSE
(
.RST        (RST),
.CLK_IN     (DATA_I_CLK),
.CLK_OUT    (DATA_O_CLK),

.PULSE_IN   (DATA_I_VLD),
.PULSE_OUT  (DATA_O_VLD)
);
*/

always @(posedge DATA_O_CLK or posedge RST)
if (RST)    
    begin
        ST          <= IDLE_ST;
        DATA_O_RDEN <= 1'b0;
        DATA_O_VLD  <= 1'b0;
    end
else case (ST)
IDLE_ST:
    begin
        if (!EMPTY)
            begin
                ST          <= WAIT_VLD_ST;
                DATA_O_RDEN <= 1'b1;
            end
        else
            begin
                ST          <= IDLE_ST;
                DATA_O_RDEN <= 1'b0;
            end    
    end
WAIT_VLD_ST:
    begin
        DATA_O_RDEN <= 1'b0;
        if (DATA_O_VALID)
            begin
                ST          <= WAIT_RD_ST;
                DATA_O_VLD  <= 1'b1;
            end
        else
            begin
                ST          <= WAIT_VLD_ST;
                DATA_O_VLD  <= 1'b0;
            end    
    end    
    
WAIT_RD_ST:
    begin
        DATA_O_VLD <= 1'b0;
        if ((!EMPTY)||(DATA_O_VALID))  ST          <= WAIT_RD_ST;
        else                           ST          <= IDLE_ST;
    end
default:
    begin
        ST          <= IDLE_ST;
        DATA_O_RDEN <= 1'b0;
        DATA_O_VLD  <= 1'b0;
    end
endcase
    


CLIENT_TO_USER_FIFO FIFO 
(
  .rst              (RST), // input rst
  
  .wr_clk           (DATA_I_CLK), // input wr_clk
  .wr_en            (DATA_I_VLD), // input wr_en
  .din              (DATA_I), // input [71 : 0] din
  
  .rd_clk           (DATA_O_CLK), // input rd_clk
  .rd_en            (DATA_O_RDEN), // input rd_en
  .dout             (DATA_O), // output [71 : 0] dout
  .valid            (DATA_O_VALID),
  
  .full             (), // output full
  .empty            (EMPTY) // output empty
);

/*
wire [35:0] CONTROL0;
	    
	     chipscope_icon_v1_06_a_0 ICON
	(	    .CONTROL0			(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILA
	(
	    .CONTROL	    (CONTROL0), // INOUT BUS [35:0]
	    .CLK			(DATA_O_CLK), // IN
	    
	    .TRIG0			({DATA_I[62:0],DATA_I_VLD}), // IN BUS [63:0]
	    .TRIG1			({DATA_O[58:0],ST,DATA_O_VLD,DATA_O_VALID,DATA_O_RDEN}) // IN BUS [63:0]
	);
*/
endmodule
