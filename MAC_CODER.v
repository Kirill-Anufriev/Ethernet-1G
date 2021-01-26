`timescale 1ns/1ps

/*
MAC_CODER	MAC_CODER_inst
#(
.HTGv6_MAC_ADDR 		()
)
(
.RST									(),
.CLK									(),

.MAC_DST_ADDR			(),				

.ARP_REQUEST				(),
.ARP_EN							(),
.ARP_DATA,						(),
.ARP_DONE						(),

.IP_REQUEST					(),
.IP_EN								(),
.IP_DATA,						(),
.IP_DONE							(),

.OUT_DATA						(),
.OUT_DATA_VLD				()
);
*/

`define ARP_PROTOCOL_TYPE_L  8'h06
`define ARP_PROTOCOL_TYPE_H  8'h08
`define IP_PROTOCOL_TYPE_L   8'h00
`define IP_PROTOCOL_TYPE_H   8'h08

/*Код типа принятого сообщения или запроса*/
`define ARP_TYPE_MES            4'b0101
`define RARP_TYPE_MES           4'b1001
`define ICMP_TYPE_MES           4'b0110
`define UDP_TYPE_MES            4'b1010
`define TCP_TYPE_MES            4'b1110
/*****************************************/

module MAC_CODER
#(
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01
)
(
input               RST,
input               CLK,

input               REQ_TYPE_VLD,
input [3:0]         REQ_TYPE,
output reg          REQ_DONE,

input[14*8-1:0]     MAC_HEADER,						// 1QW

output reg			ARP_EN,
output reg [1:0]    ARP_TYPE,
input [7:0]			ARP_DATA,
input 				ARP_DONE,

output reg			IP_EN,
output reg [1:0]    IP_TYPE,
input [7:0]			IP_DATA,
input 				IP_DONE,

output reg [7:0]	OUT_DATA,
output reg  		OUT_DATA_VLD
);

// Точно известно, что любой TCP/IP пакет несет в себе 14 байт данных заголовка MAC уровня 

localparam MAC_IDLE_ST 		     	= 5'b00000;
localparam MAC_BYTE0_ST 			= 5'b00001;
localparam MAC_BYTE1_ST 			= 5'b00011;
localparam MAC_BYTE2_ST 			= 5'b00010;
localparam MAC_BYTE3_ST 			= 5'b00110;
localparam MAC_BYTE4_ST 			= 5'b00111;
localparam MAC_BYTE5_ST 			= 5'b00101;
localparam MAC_BYTE6_ST 			= 5'b00100;
localparam MAC_BYTE7_ST 			= 5'b01100;
localparam MAC_BYTE8_ST 			= 5'b01101;
localparam MAC_BYTE9_ST 			= 5'b01111;
localparam MAC_BYTE10_ST 			= 5'b01110;
localparam MAC_BYTE11_ST 		    = 5'b01010;
localparam MAC_BYTE12_ST 			= 5'b01011;
localparam MAC_BYTE13_ST 			= 5'b01001;
localparam MAC_ARP_EN_ST 		    = 5'b01000;
localparam MAC_IP_EN_ST	 		    = 5'b11000;
localparam MAC_WAIT_ARP_IP_DONE_ST  = 5'b10000;
localparam MAC_DONE_ST 			    = 5'b10001;

(* fsm_encoding = "gray" *) 
 reg [4:0]  MAC_ST;
 wire[47:0] MAC_DST_ADDR;
 
 assign MAC_DST_ADDR = MAC_HEADER[95:48];
 
 // Формирование заголовка MAC
 always @(posedge CLK)						
 if (RST)		
 begin
 	MAC_ST 					<= MAC_IDLE_ST;
 	
	OUT_DATA				<= 8'b0;
	OUT_DATA_VLD			<= 1'b0;
	REQ_DONE				<= 1'b0;
	
	ARP_EN                  <= 1'b0;
	ARP_TYPE                <= 2'b00; 
	IP_EN                   <= 1'b0;
    IP_TYPE                 <= 2'b00;
 end																		
 else 
 (* parallel_case *)(* full_case *)
 case (MAC_ST)
MAC_IDLE_ST:	begin	
                    REQ_DONE	<= 1'b0;				
                    if (REQ_TYPE_VLD)
                        begin
                            if (REQ_TYPE == 4'b0000)
                                begin
                                    MAC_ST          <= MAC_IDLE_ST;
                                end
                            else     
                                begin
                                    MAC_ST          <= MAC_BYTE0_ST;
                                end
                        end
                     else 
                        begin
                            MAC_ST <= MAC_IDLE_ST;
                        end   
                 end                        
// Формирование даных DESTINATION ADDRESS
MAC_BYTE0_ST:							begin
 															MAC_ST 								<= MAC_BYTE1_ST;
 															OUT_DATA							<= MAC_DST_ADDR[47:40];
 															OUT_DATA_VLD					    <= 1'b1;
 													end
MAC_BYTE1_ST:							begin
 															MAC_ST 								<= MAC_BYTE2_ST;
 															OUT_DATA							<= MAC_DST_ADDR[39:32];
 													end
MAC_BYTE2_ST:							begin                                                                          													
 															MAC_ST 								<= MAC_BYTE3_ST;                                                     														
 															OUT_DATA							<= MAC_DST_ADDR[31:24];                                          														
 													end                              
MAC_BYTE3_ST:							begin                                                                          
 															MAC_ST 								<= MAC_BYTE4_ST;                                                     
 															OUT_DATA							<= MAC_DST_ADDR[23:16];                                            
 													end                                                                                   
MAC_BYTE4_ST:							begin                                                                          
 															MAC_ST 								<= MAC_BYTE5_ST;                                                     
 															OUT_DATA							<= MAC_DST_ADDR[15:8];                                            
 													end                                                                                   
MAC_BYTE5_ST:							begin                                                                          
 															MAC_ST 								<= MAC_BYTE6_ST;                                                     
 															OUT_DATA							<= MAC_DST_ADDR[7:0];                                           
 													end    
// Формирование данных SOURCE ADDRESS													                                                                               
MAC_BYTE6_ST:							begin                                                                          
 															MAC_ST 								<= MAC_BYTE7_ST;                                                     													                                                     														
 															OUT_DATA							<= HTGv6_MAC_ADDR[47:40];                                           														
 													end                                                                                   			
MAC_BYTE7_ST:							begin                                                                          			
 															MAC_ST 								<= MAC_BYTE8_ST;                                                     			
 															OUT_DATA							<= HTGv6_MAC_ADDR[39:32];                                             			
 													end                                                                                   			
MAC_BYTE8_ST:							begin                                                                          			
 															MAC_ST 								<= MAC_BYTE9_ST;                                                     			
 															OUT_DATA							<= HTGv6_MAC_ADDR[31:24];                                             			
 													end                                                                                   			
MAC_BYTE9_ST:							begin                                                                          			
 															MAC_ST 								<= MAC_BYTE10_ST;                                                     			
 															OUT_DATA							<= HTGv6_MAC_ADDR[23:16];                                             			
 													end                                                                                   			
MAC_BYTE10_ST:							begin                                                                          			
 															MAC_ST 								<= MAC_BYTE11_ST;                                                     			
 															OUT_DATA							<= HTGv6_MAC_ADDR[15:8];                                            			
 													end                                                                                   			
MAC_BYTE11_ST:							begin                                                                          			
 															MAC_ST 								<= MAC_BYTE12_ST;                                                     			
 															OUT_DATA							<= HTGv6_MAC_ADDR[7:0];                                            			
 													end   
 // Формирование даных PROTOCOL TYPE													
MAC_BYTE12_ST:						begin                                                                          			
 										MAC_ST 								        <= MAC_BYTE13_ST;                                                     			
 										case (REQ_TYPE)
 							/*ARP*/		     `ARP_TYPE_MES:
 										         begin
 										             ARP_EN	     <= 1'b1;
 										             ARP_TYPE	 <= REQ_TYPE[3:2];
 										             OUT_DATA    <= `ARP_PROTOCOL_TYPE_H;
 										         end
							/*RARP*/         `RARP_TYPE_MES:
  										         begin
  										             ARP_EN	     <= 1'b1;                 
  										             ARP_TYPE	 <= REQ_TYPE[3:2];                  
  										             OUT_DATA    <= `ARP_PROTOCOL_TYPE_H; 
  										         end
 							/*ICMP*/		 `ICMP_TYPE_MES:
 							                     begin
 							                         IP_EN	     <= 1'b1;                
 							                         IP_TYPE	 <= REQ_TYPE[3:2];                 
 							                         OUT_DATA    <= `IP_PROTOCOL_TYPE_H;
 							                     end
 							/*UDP*/          `UDP_TYPE_MES:
 							                     begin
 							                         IP_EN	     <= 1'b1;                
 							                         IP_TYPE	 <= REQ_TYPE[3:2];                 
 							                         OUT_DATA    <= `IP_PROTOCOL_TYPE_H;
 							                     end
 							/*TCP*/     /*     `TCP_TYPE_MES:
 							                     begin
 							                      	 IP_EN	     <= 1'b1;                
                                                     IP_TYPE	 <= REQ_TYPE[3:2];         
                                                     OUT_DATA    <= `IP_PROTOCOL_TYPE_H;
 							                     end      */  	
 							                 default:   
 							                     begin           
 							                         ARP_EN	     <= 1'b0; 
                                                     ARP_TYPE	 <= ARP_TYPE;    
                                                     IP_EN	     <= 1'b0;                
                                                     IP_TYPE	 <= IP_TYPE;         
                                                     OUT_DATA    <= 8'b0;
                                                 end                                    
 							              endcase
 							          end         
 										
MAC_BYTE13_ST:						begin						
										ARP_EN								<= 1'b0;
								    	IP_EN								<= 1'b0;
         								case (REQ_TYPE)
         						/*ARP*/     `ARP_TYPE_MES:
         								         begin
         								             MAC_ST 	 <= MAC_ARP_EN_ST;
         								             OUT_DATA    <= `ARP_PROTOCOL_TYPE_L;
         								         end
         						/*RARP*/     `RARP_TYPE_MES:
         								         begin
         								             MAC_ST 	 <= MAC_ARP_EN_ST;                 
         								             OUT_DATA    <= `ARP_PROTOCOL_TYPE_L; 
         								         end
         						/*ICMP*/    `ICMP_TYPE_MES:
         						                begin
         						                     MAC_ST 	 <= MAC_IP_EN_ST;
         						                     OUT_DATA    <= `IP_PROTOCOL_TYPE_L;
         						                end
         						/*UDP*/     `UDP_TYPE_MES:
         						                begin
         						                     MAC_ST 	 <= MAC_IP_EN_ST;
         						                     OUT_DATA    <= `IP_PROTOCOL_TYPE_L;
         						                end
         						/*TCP*//*     `TCP_TYPE_MES:
         						                begin
         						                     MAC_ST 	 <= MAC_IP_EN_ST;
                                                     OUT_DATA    <= `IP_PROTOCOL_TYPE_L;
         						                end      */  	
         						            default:   
         						                begin           
                                                     MAC_ST      <= MAC_ST;
                                                     OUT_DATA    <= 8'b0;
                                                 end                                    
         						       endcase
         						    end        

MAC_ARP_EN_ST:						begin
							     			OUT_DATA						 <= ARP_DATA;							
											MAC_ST							 <= MAC_WAIT_ARP_IP_DONE_ST;
									end		
MAC_IP_EN_ST:						begin
											OUT_DATA						 <= IP_DATA;							
											MAC_ST							 <= MAC_WAIT_ARP_IP_DONE_ST;
									end
MAC_WAIT_ARP_IP_DONE_ST:    if ((REQ_TYPE == `ARP_TYPE_MES)||(REQ_TYPE == `RARP_TYPE_MES))	
                                begin
                                     if (ARP_DONE)
                                         begin
                                             MAC_ST 				<= MAC_DONE_ST;
                                         	OUT_DATA			<= 8'b0;
                                         	OUT_DATA_VLD        <= 1'b0;
                                         end
                                     else
                                         begin
                                             MAC_ST 			<= MAC_WAIT_ARP_IP_DONE_ST;
                                             OUT_DATA		<= ARP_DATA;
                                         end    
                                 end
                             else if ((REQ_TYPE == `ICMP_TYPE_MES)||(REQ_TYPE == `UDP_TYPE_MES)||(REQ_TYPE == `TCP_TYPE_MES)) 
                                 begin
                                     if (IP_DONE)
                                         begin
                                             MAC_ST 				<= MAC_DONE_ST;
                                         	OUT_DATA			<= 8'b0;
                                         	OUT_DATA_VLD        <= 1'b0;
                                         end
                                     else
                                         begin
                                             MAC_ST 			<= MAC_WAIT_ARP_IP_DONE_ST;
                                             OUT_DATA		<= IP_DATA;
                                         end    
                                 end
MAC_DONE_ST:			 	begin	
								REQ_DONE				<= 1'b1;	
								MAC_ST	 				<= MAC_IDLE_ST;
							end	
default:        			begin
 								MAC_ST 					<= MAC_IDLE_ST;                 
 								                                            
 								OUT_DATA				<= 8'b0;                            
 								OUT_DATA_VLD			<= 1'b0;                         
 								REQ_DONE				<= 1'b0;                            
 								                                            
 								ARP_EN                  <= 1'b0;             
 								ARP_TYPE                <= ARP_TYPE;            
 								IP_EN                   <= 1'b0;             
 								IP_TYPE                 <= IP_TYPE; 
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
	    
	    .TRIG0			({MAC_ST,IP_DONE,IP_TYPE,IP_EN,ARP_DONE,ARP_EN,REQ_DONE,REQ_TYPE,REQ_TYPE_VLD}), // IN BUS [63:0]
	    .TRIG1			(64'b0) // IN BUS [63:0]
	);
*/
endmodule