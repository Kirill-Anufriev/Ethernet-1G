`timescale 1ns / 1ps
/*
Модуль для создания пакетов формата ARP
*/

/*
ARP_CODER	ARP_CODER_inst
#(
.HTGv6_IP_ADDR 					(),
.HTGv6_MAC_ADDR 				(),
)
(
.RST							(),
.CLK							(),

.ARP_EN							(),
.ARP_TYPE                       (),
.ARP_OUT_DATA					(),
.ARP_DONE						()
);
*/

`define ARP_RESPOND  16'h0002
`define RARP_RESPOND 16'h0004

`define ARP_TYPE_MES  2'b01
`define RARP_TYPE_MES 2'b10

module ARP_CODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01
)
(
input 				RST,
input 				CLK,

input               MESS_DONE,

input [28*8-1:0]    ARP_HEADER,				

input 				ARP_EN,
input [1:0]         ARP_TYPE,
output reg [7:0]	ARP_OUT_DATA,
output reg 		    ARP_DONE
);

localparam ARP_BYTE0_ST 	= 5'b00000;
localparam ARP_BYTE1_ST 	= 5'b00001;
localparam ARP_BYTE2_ST 	= 5'b00011;
localparam ARP_BYTE3_ST 	= 5'b00010;
localparam ARP_BYTE4_ST 	= 5'b00110;
localparam ARP_BYTE5_ST 	= 5'b00111;
localparam ARP_BYTE6_ST 	= 5'b00101;
localparam ARP_BYTE7_ST 	= 5'b00100;
localparam ARP_BYTE8_ST 	= 5'b01100;
localparam ARP_BYTE9_ST 	= 5'b01101;
localparam ARP_BYTE10_ST 	= 5'b01111;
localparam ARP_BYTE11_ST  	= 5'b01110;
localparam ARP_BYTE12_ST  	= 5'b01010;
localparam ARP_BYTE13_ST  	= 5'b01011;
localparam ARP_BYTE14_ST  	= 5'b01001;
localparam ARP_BYTE15_ST  	= 5'b01000;
localparam ARP_BYTE16_ST  	= 5'b11000;
localparam ARP_BYTE17_ST  	= 5'b11001;
localparam ARP_BYTE18_ST  	= 5'b11011;
localparam ARP_BYTE19_ST  	= 5'b11010;
localparam ARP_BYTE20_ST  	= 5'b11110;
localparam ARP_BYTE21_ST  	= 5'b11111;
localparam ARP_BYTE22_ST  	= 5'b11101;
localparam ARP_BYTE23_ST  	= 5'b11100;
localparam ARP_BYTE24_ST  	= 5'b10100;
localparam ARP_BYTE25_ST  	= 5'b10101;
localparam ARP_BYTE26_ST  	= 5'b10111;
localparam ARP_BYTE27_ST  	= 5'b10110;
localparam ARP_DONE_ST  	= 5'b10010;

wire [47:0] ARP_DST_PHY_ADDR;
wire [31:0] ARP_DST_IP;
reg  [15:0] ARP_HEADER_TYPE = 16'b0;
wire [15:0] ARP_HARDW_TYPE;								// Тип используемой сети (1 - Ethernet)										// Учебник. Олифер "Компьютерные сети" стр 498
wire [15:0] ARP_PROT_TYPE;									// Тип прооколоа сообщения (16h0800 - ARP)
wire [7:0]  ARP_HARDW_ADDR_LEN;						// Длина локального (МАС) адреса для ARP = 6 байт стандартно
wire [7:0]  ARP_PROT_ADDR_LEN;							// Длина иерархического (IP) адреса для ARP = 4 байта стандартно


assign ARP_DST_PHY_ADDR     = ARP_HEADER[111:64];
assign ARP_DST_IP           = ARP_HEADER[143:112];

always @(ARP_TYPE)
if      (ARP_TYPE == `ARP_TYPE_MES)  ARP_HEADER_TYPE <= `ARP_RESPOND;
else if (ARP_TYPE == `RARP_TYPE_MES) ARP_HEADER_TYPE <= `RARP_RESPOND;
else                        ARP_HEADER_TYPE <= ARP_HEADER;
//assign ARP_HEADER_TYPE      = (ARP_TYPE == 2'b00)?`ARP_RESPOND:
//                              (ARP_TYPE == 2'b01)?`RARP_RESPOND: ARP_HEADER_TYPE;

assign ARP_HARDW_TYPE 		= 16'd1;					
assign ARP_PROT_TYPE		= 16'h0800;				
assign ARP_HARDW_ADDR_LEN	= 8'd6;						
assign ARP_PROT_ADDR_LEN	= 8'd4;					


(* fsm_encoding = "gray" *) 
reg [4:0] ARP_ST;

always @(posedge CLK or posedge RST)
if (RST)							
begin
	ARP_ST 								<= ARP_BYTE0_ST;
	ARP_OUT_DATA 					<= 0;
	ARP_DONE   						<= 0;
end
else 
(* parallel_case *)(* full_case *)
case (ARP_ST)
// Формирование данных ARP_HARDW_TYPE
ARP_BYTE0_ST:				if (ARP_EN)	
													begin
															ARP_ST 							<= ARP_BYTE1_ST;
															ARP_OUT_DATA					<= ARP_HARDW_TYPE[15:8];
															ARP_DONE						<= 0;
													end
										else 					
													begin
															ARP_ST 							<= ARP_BYTE0_ST;
															ARP_OUT_DATA					<= ARP_HARDW_TYPE[15:8];
															ARP_DONE						<= 0;
													end
ARP_BYTE1_ST:							begin
															ARP_ST 							<= ARP_BYTE2_ST;
															ARP_OUT_DATA					<= ARP_HARDW_TYPE[7:0];
													end
// Формирование данных ARP_PROT_TYPE													
ARP_BYTE2_ST:							begin                                                                          													
															ARP_ST 							<= ARP_BYTE3_ST;                                                     														
															ARP_OUT_DATA					<= ARP_PROT_TYPE[15:8];                                            														
													end  
ARP_BYTE3_ST:							begin                                                                          
															ARP_ST 							<= ARP_BYTE4_ST;                                                     
															ARP_OUT_DATA					<= ARP_PROT_TYPE[7:0];                                           
													end     
// Формирование данных ARP_HARDW_ADDR_LEN		
ARP_BYTE4_ST:							begin                                                                          
															ARP_ST 							<= ARP_BYTE5_ST;                                                     
															ARP_OUT_DATA					<= ARP_HARDW_ADDR_LEN;                                             
													end      
// Формирование данных ARP_PROT_ADDR_LEN
ARP_BYTE5_ST:							begin                                                                          
															ARP_ST 							<= ARP_BYTE6_ST;                                                     
															ARP_OUT_DATA					<= ARP_PROT_ADDR_LEN;                                              
													end    
// Формирование данных ARP_TYPE	
ARP_BYTE6_ST:							begin                                                                          
															ARP_ST 							<= ARP_BYTE7_ST;                                                     													                                                     														
															ARP_OUT_DATA					<= ARP_HEADER_TYPE[15:8];                                            														
													end    
ARP_BYTE7_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE8_ST;                                                     			
															ARP_OUT_DATA					<= ARP_HEADER_TYPE[7:0];                                           			
													end                                                                                   			
// Формирование данных ARP_SRC_PHY_ADDR	
ARP_BYTE8_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE9_ST;                                                     			
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[47:40];                                             			
													end                                                                                   			
ARP_BYTE9_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE10_ST;                                                     			
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[39:32];                                             			
													end                                                                                   			
ARP_BYTE10_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE11_ST;                                                     			
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[31:24];                                               			
													end                                                                                   			
ARP_BYTE11_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE12_ST;                                                     			
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[23:16];                                               			
													end   
ARP_BYTE12_ST:							begin                                                                          			
															ARP_ST 							<= ARP_BYTE13_ST;                                                     			
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[15:8];                                               			
													end                                                                                   			
ARP_BYTE13_ST:							begin
															ARP_ST							<= ARP_BYTE14_ST;
															ARP_OUT_DATA					<= HTGv6_MAC_ADDR[7:0];    		
													end
// Формирование данных 	ARP_SRC_IP
ARP_BYTE14_ST:							begin                                                                                    													
															ARP_ST 							<= ARP_BYTE15_ST;                                                               													
															ARP_OUT_DATA					<= HTGv6_IP_ADDR[31:24];                                                      													
													end                                                                                             													
ARP_BYTE15_ST:							begin                                                                          																							
															ARP_ST 							<= ARP_BYTE16_ST;                                                     																							
															ARP_OUT_DATA					<= HTGv6_IP_ADDR[23:16];                                            																							
													end                                                                                             													
ARP_BYTE16_ST:							begin                                                                                    													
															ARP_ST 							<= ARP_BYTE17_ST;                                                               													
															ARP_OUT_DATA					<= HTGv6_IP_ADDR[15:8];                                                      													
													end                                                                                             													
ARP_BYTE17_ST:							begin                                                                                    													
															ARP_ST 							<= ARP_BYTE18_ST;                                                               													
															ARP_OUT_DATA					<= HTGv6_IP_ADDR[7:0];                                                       													
													end   
// Формирование данных ARP_DST_PHY_ADDR														                                                                                          													
ARP_BYTE18_ST:							begin                                                                                    													
															ARP_ST 							<= ARP_BYTE19_ST;                                                               													
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[47:40];                                                         													
													end                                                                                             													
ARP_BYTE19_ST:							begin                                                                                    													
															ARP_ST 							<= ARP_BYTE20_ST;                                                     																							
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[39:32];                                          																								
													end                                                                                   			       													
ARP_BYTE20_ST:							begin                                                                          			       													
															ARP_ST 							<= ARP_BYTE21_ST;                                                     			       													
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[31:24];                                           			        													
													end                                                                                   			       													
ARP_BYTE21_ST:							begin                                                                          			       													
															ARP_ST 							<= ARP_BYTE22_ST;                                                     			       													
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[23:16];                                             			        													
													end                                                                                   			       													
ARP_BYTE22_ST:							begin                                                                          			       													
															ARP_ST 							<= ARP_BYTE23_ST;                                                     			      													
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[15:8];                                           			        													
													end                                                                                   			       													
ARP_BYTE23_ST:							begin                                                                          			      													
															ARP_ST 							<= ARP_BYTE24_ST;                                                     			      													
															ARP_OUT_DATA					<= ARP_DST_PHY_ADDR[7:0];                                          			        													
													end        
// Формирование данных 	ARP_DST_IP													                                                                          			       													
ARP_BYTE24_ST:							begin                                                                          			      													
															ARP_ST 							<= ARP_BYTE25_ST;                                                     			      													
															ARP_OUT_DATA					<= ARP_DST_IP[31:24];                                             			         													
													end                                                                                             													
ARP_BYTE25_ST:							begin                                                                          			      													
															ARP_ST 							<= ARP_BYTE26_ST;                                                     			    													
															ARP_OUT_DATA					<= ARP_DST_IP[23:16];                                          			    													
													end                                                                                   			       													
ARP_BYTE26_ST:							begin                                                                                   													
															ARP_ST							<= ARP_BYTE27_ST;                                                          													
															ARP_OUT_DATA					<= ARP_DST_IP[15:8];
															ARP_DONE   						<= 0;			                                                 													
													end                                                                                             													
ARP_BYTE27_ST:							begin                                                                                   																	
															ARP_ST							<= ARP_DONE_ST;                                                          																	
															ARP_OUT_DATA					<= ARP_DST_IP[7:0];
													end                                                                                             																	
ARP_DONE_ST:									
													begin
															ARP_ST							<= ARP_BYTE0_ST; 	
															ARP_OUT_DATA					<= 0;
															ARP_DONE   						<= 1;
													end		
default:
													begin
															ARP_ST 							<= ARP_BYTE0_ST;
															ARP_OUT_DATA 					<= 0;
															ARP_DONE   						<= 0;
													end
endcase

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
	    
	    .TRIG0			({ARP_HEADER[45:0],MESS_DONE,ARP_ST,ARP_OUT_DATA,ARP_TYPE,ARP_DONE,ARP_EN}), // IN BUS [63:0]
	    .TRIG1			(ARP_HEADER[109:46]) // IN BUS [63:0]
	);
*/

endmodule
