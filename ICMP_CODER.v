`timescale 1ns/1ps

`define ICMP_REPLY_TYPE 8'd0

module ICMP_CODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01
)
(
input RST,
input CLK,

// ICMP данные
output reg		ICMP_DATA_REQ,
input [7:0] 	ICMP_IN_DATA,
input 			ICMP_IN_DATA_VLD,

input           ICMP_EN,
input[8*8+4-1:0]ICMP_HEADER,
output reg [7:0]ICMP_OUT_DATA,
output reg		ICMP_DONE
);

localparam ICMP_BYTE0_ST = 4'b0001;
localparam ICMP_BYTE1_ST = 4'b0011;       
localparam ICMP_BYTE2_ST = 4'b0010;       
localparam ICMP_BYTE3_ST = 4'b0110;
localparam ICMP_BYTE4_ST = 4'b0111;     
localparam ICMP_BYTE5_ST = 4'b0101;
localparam ICMP_BYTE6_ST = 4'b0100;
localparam ICMP_BYTE7_ST = 4'b1100;
localparam ICMP_DATA_ST	 = 4'b1101;
localparam ICMP_DONE_ST  = 4'b1001; 

(* fsm_encoding = "gray" *) 
reg [3:0]  ICMP_ST;
reg [19:0] CHECKSUM;
reg [15:0] ICMP_OUT_CHECKSUM;

wire [7:0]  ICMP_TYPE;
wire [7:0]  ICMP_CODE;
wire [19:0] ICMP_DATA_CHECKSUM;  // Контрольную сумму именно данных считаем при приеме данных
wire [15:0] ICMP_IDENTIFIER;
wire [15:0] ICMP_SEQUENCER;

assign ICMP_TYPE            = ICMP_HEADER[7:0];
assign ICMP_CODE            = ICMP_HEADER[15:8];
assign ICMP_DATA_CHECKSUM   = ICMP_HEADER[35:16];
assign ICMP_IDENTIFIER      = ICMP_HEADER[51:36];
assign ICMP_SEQUENCER       = ICMP_HEADER[67:52];

always @(posedge CLK or posedge RST)
if (RST)							
begin
	ICMP_ST 			<= ICMP_BYTE0_ST;
	ICMP_DONE 		    <= 0;	
	ICMP_OUT_DATA		<= 0;
	ICMP_DATA_REQ		<= 0;
	ICMP_OUT_CHECKSUM   <= 0;
end
else 
(* parallel_case *)(* full_case *)
case (ICMP_ST)
// Формирование даных ICMP_TYPE
ICMP_BYTE0_ST:							if (ICMP_EN)	
														begin
															ICMP_ST 			<= ICMP_BYTE1_ST;
															ICMP_OUT_DATA		<= (ICMP_TYPE == 8'd8)?8'd0:ICMP_OUT_DATA;
															ICMP_DONE			<= 0;
														end
													else 					
														begin
															ICMP_ST 			<= ICMP_BYTE0_ST;
															ICMP_OUT_DATA		<= (ICMP_TYPE == 8'd8)?8'd0:ICMP_OUT_DATA;
															ICMP_DONE			<= 0;
														end
// Формирование даных ICMP_CODE												
ICMP_BYTE1_ST:								begin
															ICMP_ST 			<= ICMP_BYTE2_ST;
															ICMP_OUT_CHECKSUM   <= ~({12'b0,CHECKSUM [19:16]} + CHECKSUM [15:0]);
															ICMP_OUT_DATA		<= ICMP_CODE;
														end
// Формирование даных ICMP_OUT_CHECKSUM													
ICMP_BYTE2_ST:								begin                                                                          													
															ICMP_ST 			<= ICMP_BYTE3_ST;                                                     														
															ICMP_OUT_DATA		<= ICMP_OUT_CHECKSUM[15:8];                                           														
														end  
ICMP_BYTE3_ST:								begin                                                                          
															ICMP_ST 			<= ICMP_BYTE4_ST;                                                     
															ICMP_OUT_DATA		<= ICMP_OUT_CHECKSUM[7:0];                                           
														end     
// Формирование даных ICMP_IDENTIFIER		
ICMP_BYTE4_ST:								begin                                                                          
															ICMP_ST 			<= ICMP_BYTE5_ST;                                                     
															ICMP_OUT_DATA		<= ICMP_IDENTIFIER[15:8];                                           
														end      
ICMP_BYTE5_ST:								begin                                                                          
															ICMP_ST				<= ICMP_BYTE6_ST;                                                     
															ICMP_OUT_DATA		<= ICMP_IDENTIFIER[7:0];                                           
														end    
// Формирование даных ICMP_SEQUENCER
ICMP_BYTE6_ST:								begin                                                                          
															ICMP_ST				<= ICMP_BYTE7_ST;                                                     													                                                     														
															ICMP_OUT_DATA		<= ICMP_SEQUENCER[15:8];   
															ICMP_DATA_REQ		<= 1;                                        														
														end    
ICMP_BYTE7_ST:								begin                                                                          			
															ICMP_ST 			<= ICMP_DATA_ST;                                                     			
															ICMP_OUT_DATA		<= ICMP_SEQUENCER[7:0]; 
															ICMP_DATA_REQ		<= 0;                                        			
														end  
// Формирование даных из поля данных ICMP	
ICMP_DATA_ST:								if (ICMP_IN_DATA_VLD)	
														begin
														    ICMP_ST 			<= ICMP_DATA_ST;
															ICMP_OUT_DATA		<= ICMP_IN_DATA;     
														end
										    else 		
													    begin
															ICMP_ST			    <= ICMP_DONE_ST;
															ICMP_OUT_DATA		<= 0;   
															ICMP_DONE 			<= 1;	  
												    	end
ICMP_DONE_ST:							begin	
														    ICMP_ST 		    <= ICMP_BYTE0_ST; 
														    ICMP_OUT_CHECKSUM   <= 0;
														    ICMP_DONE           <= 0;
													end	
default:
													begin
														    ICMP_ST 			<= ICMP_BYTE0_ST;
														    ICMP_OUT_DATA		<= 0;
														    ICMP_DATA_REQ		<= 0;
													end
endcase												

always @(posedge CLK or posedge RST)
if (RST)            CHECKSUM <= 0;
else if (ICMP_EN)   CHECKSUM <= {12'b0,ICMP_CODE} + {4'b0,ICMP_IDENTIFIER} + {4'b0,ICMP_SEQUENCER} + ICMP_DATA_CHECKSUM[15:0] + {12'b0,ICMP_DATA_CHECKSUM[19:16]};
else if (ICMP_DONE) CHECKSUM <= 0;
else                CHECKSUM <= CHECKSUM;

//assign CHECKSUM = {12'b0,ICMP_CODE} + {4'b0,ICMP_IDENTIFIER} + {4'b0,ICMP_SEQUENCER} + ICMP_DATA_CHECKSUM;

/*always @(posedge CLK)
if (RST)													CHECKSUM <= 0;
else if (ICMP_ST == ICMP_BYTE0_ST)		                    CHECKSUM <= {12'b0,ICMP_CODE} + {4'b0,ICMP_IDENTIFIER} + {4'b0,ICMP_SEQUENCER} + ICMP_DATA_CHECKSUM;
else if (ICMP_ST == ICMP_DONE_ST)		                    CHECKSUM <= 0;
*/

/*
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// Отладка CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [35:0] CONTROL0;

	     chipscope_icon_v1_06_a_0 ICON
	(	    .CONTROL0			(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILA
	(
	    .CONTROL	    (CONTROL0), // INOUT BUS [35:0]
	    .CLK			(CLK), // IN
	    
	    .TRIG0			({ICMP_DATA_CHECKSUM,CHECKSUM,ICMP_OUT_CHECKSUM,ICMP_DONE,ICMP_EN}), // IN BUS [63:0]
	    .TRIG1			({24'b0,ICMP_CODE,ICMP_IDENTIFIER,ICMP_SEQUENCER}) // IN BUS [63:0]
	);
*/

endmodule