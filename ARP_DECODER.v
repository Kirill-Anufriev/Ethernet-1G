`timescale 1ns / 1ps

/*
Декодер принимаемых ARP запросов

Кроме того еще существуют RARP - Reverse ARP, определяющие IP адрес по известному MAC. Если на сервере для нашего устройства с известным серверу МАС адресом выделился IP адрес, 
то, послав RARP серверу с нашим МАС адресом в поле RARP запроса, в отвере от севервера получаем значение IP , которое он выделил нашему устройству 

Модуль обрабатывает ARP сообщение и выдает запрос без подтверждения на формирование ответного ARP.
В случае, если IP адрес назначения не соответствует IP адресу нашего устройства, ARP модуль переходит в состояние DONE, и передает сигнал об этом МАС уровню
*/

/*
ARP_DECODER
#(
.HTGv6_IP_ADDR 			(),
.HTGv6_MAC_ADDR 		()
)
ARP_DECODER_inst
(
.RST					(),
.CLK				    (),

.IN_DATA				(),				// [63:0]
.IN_DATA_VLD	       	(),

.ARP_EN					(),
.ARP_HEADER             (),
.ARP_DONE				(),    // [28*8-1:0]
);
*/
`define ARP_REQUEST   16'h0001
`define RARP_REQUEST  16'h0003

`define UNSUPPORTED_TYPE_MES    2'b00
`define ARP_TYPE_MES            2'b01
`define RARP_TYPE_MES           2'b10

module ARP_DECODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01
)
(
input 				RST,
input 				CLK,

input [7:0]			IN_DATA,
input 				IN_DATA_VLD,

input				 ARP_EN,
output reg [28*8-1:0]ARP_HEADER,
output reg [1:0]     ARP_TYPE,         // 2'b00 - Если приняли сообщение , обращенное не к нам, или с ошибкой, 2'b01 - ARP запрос, 2'b10 - RARP запрос,       
output reg 			 ARP_DONE
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
localparam ARP_REQUEST_ST  	= 5'b10010;
localparam ARP_DONE_ST  	= 5'b10000;

(* fsm_encoding = "gray" *)
reg [4:0] ARP_ST;

reg [15:0] ARP_MESS_TYPE;     
reg [47:0] ARP_SRC_PHY_ADDR;	 
reg [31:0] ARP_SRC_IP;
reg [15:0] ARP_HARDW_TYPE;			// Тип используемой сети (1 - Ethernet)										// Учебник. Олифер "Компьютерные сети" стр 498
reg [15:0] ARP_PROT_TYPE;			// Тип прооколоа сообщения (16h0800 - ARP)
reg [7:0]  ARP_HARDW_ADDR_LEN;		// Длина локального (МАС) адреса для ARP = 6 байт стандартно
reg [7:0]  ARP_PROT_ADDR_LEN;		// Длина иерархического (IP) адреса для ARP = 4 байта стандартно
reg [47:0] ARP_DST_PHY_ADDR;				
reg [31:0] ARP_DST_IP;								

always @(posedge CLK or posedge RST)
if (RST)							
begin
	ARP_ST 					<= ARP_BYTE0_ST;
	ARP_HEADER              <= 224'b0;
	ARP_TYPE                <= 2'b0;
	ARP_DONE				<= 1'b0;
	
	ARP_MESS_TYPE           <= 16'b0;		
    ARP_SRC_PHY_ADDR        <= 48'b0;		 
    ARP_SRC_IP              <= 32'b0;
	ARP_HARDW_TYPE 			<= 16'b0;
	ARP_PROT_TYPE   		<= 16'b0;
	ARP_HARDW_ADDR_LEN	    <= 8'b0;
	ARP_PROT_ADDR_LEN		<= 8'b0;
	ARP_DST_PHY_ADDR		<= 48'b0;
	ARP_DST_IP				<= 32'b0;
end
else 
(* parallel_case *)(* full_case *)
case (ARP_ST)
// Прием даных ARP_HARDW_TYPE
ARP_BYTE0_ST:				if (ARP_EN)	
								begin
									ARP_ST 						<= ARP_BYTE1_ST;
									ARP_HARDW_TYPE[15:8]		<= IN_DATA;
								    ARP_DONE					<= 1'b0;
								end
							else 					
								begin
									ARP_ST 						<= ARP_BYTE0_ST;
						      		ARP_HARDW_TYPE[15:8]		<= ARP_HARDW_TYPE[15:8];
									ARP_DONE					<= 1'b0;
								end
ARP_BYTE1_ST:				begin
									ARP_ST 						<= ARP_BYTE2_ST;
									ARP_HARDW_TYPE[7:0]		    <= IN_DATA;
							end
// Прием даных ARP_PROT_TYPE													
ARP_BYTE2_ST:				begin                                                                          													
									ARP_ST 						<= ARP_BYTE3_ST;                                                     														
									ARP_PROT_TYPE[15:8]		    <= IN_DATA;                                            														
							end  
ARP_BYTE3_ST:				begin                                                                          
									ARP_ST 						<= ARP_BYTE4_ST;                                                     
									ARP_PROT_TYPE[7:0]			<= IN_DATA;                                            
							end     
// Прием даных ARP_HARDW_ADDR_LEN		
ARP_BYTE4_ST:				begin                                                                          
									ARP_ST 						<= ARP_BYTE5_ST;                                                     
									ARP_HARDW_ADDR_LEN	        <= IN_DATA;                                            
							end      
// Прием даных ARP_PROT_ADDR_LEN
ARP_BYTE5_ST:				begin                                                                          
									ARP_ST 						<= ARP_BYTE6_ST;                                                     
									ARP_PROT_ADDR_LEN		    <= IN_DATA;                                            
							end    
// Прием даных ARP_TYPE	
ARP_BYTE6_ST:				begin                                                                          
									ARP_ST 						<= ARP_BYTE7_ST;                                                     													                                                     														
									ARP_MESS_TYPE[15:8]		    <= IN_DATA;                                            														
							end    
ARP_BYTE7_ST:				begin                                                                          			
									ARP_ST						<= ARP_BYTE8_ST;                                                     			
									ARP_MESS_TYPE[7:0]			<= IN_DATA;                                            			
							end                                                                                   			
// Прием даных ARP_SRC_PHY_ADDR	
ARP_BYTE8_ST:				begin                                                                          			
									ARP_ST 					    <= ARP_BYTE9_ST;                                                     			
									ARP_SRC_PHY_ADDR[47:40]     <= IN_DATA;                                            			
							end                                                                                   			
ARP_BYTE9_ST:				begin                                                                          			
						      		ARP_ST 						<= ARP_BYTE10_ST;                                                     			
									ARP_SRC_PHY_ADDR[39:32]     <= IN_DATA;                                            			
							end                                                                                   			
ARP_BYTE10_ST:				begin                                                                          			
									ARP_ST 						<= ARP_BYTE11_ST;                                                     			
									ARP_SRC_PHY_ADDR[31:24]     <= IN_DATA;                                            			
						    end                                                                                   			
ARP_BYTE11_ST:				begin                                                                          			
									ARP_ST 						<= ARP_BYTE12_ST;                                                     			
									ARP_SRC_PHY_ADDR[23:16]     <= IN_DATA;                                            			
							end   
ARP_BYTE12_ST:				begin                                                                          			
									ARP_ST 						<= ARP_BYTE13_ST;                                                     			
									ARP_SRC_PHY_ADDR[15:8]	    <= IN_DATA;                                            			
							end                                                                                   			
ARP_BYTE13_ST:				begin
									ARP_ST						<= ARP_BYTE14_ST;
									ARP_SRC_PHY_ADDR[7:0]	    <= IN_DATA; 		
							end
// Прием даных 	ARP_SRC_IP
ARP_BYTE14_ST:				begin                                                                                    													
									ARP_ST 						<= ARP_BYTE15_ST;                                                               													
									ARP_SRC_IP[31:24]		    <= IN_DATA;                                                      													
							end                                                                                             													
ARP_BYTE15_ST:				begin                                                                          																							
									ARP_ST 						<= ARP_BYTE16_ST;                                                     																							
									ARP_SRC_IP[23:16]		    <= IN_DATA;                                            																							
							end                                                                                             													
ARP_BYTE16_ST:				begin                                                                                    													
									ARP_ST 						<= ARP_BYTE17_ST;                                                               													
									ARP_SRC_IP[15:8]		    <= IN_DATA;                                                      													
							end                                                                                             													
ARP_BYTE17_ST:				begin                                                                                    													
									ARP_ST 						<= ARP_BYTE18_ST;                                                               													
									ARP_SRC_IP[7:0]			    <= IN_DATA;                                                       													
							end   
// Прием даных ARP_DST_PHY_ADDR														                                                                                          													
ARP_BYTE18_ST:				begin                                                                                    													
									ARP_ST 						<= ARP_BYTE19_ST;                                                               													
									ARP_DST_PHY_ADDR[47:40]     <= IN_DATA;                                                        													
						    end                                                                                             													
ARP_BYTE19_ST:				begin                                                                                    													
									ARP_ST 						<= ARP_BYTE20_ST;                                                     																							
									ARP_DST_PHY_ADDR[39:32]     <= IN_DATA;                                            																								
							end                                                                                   			       													
ARP_BYTE20_ST:				begin                                                                          			       													
									ARP_ST 						<= ARP_BYTE21_ST;                                                     			       													
									ARP_DST_PHY_ADDR[31:24]     <= IN_DATA;                                            			        													
							end                                                                                   			       													
ARP_BYTE21_ST:				begin                                                                     			       													
									ARP_ST 						<= ARP_BYTE22_ST;                                                     			       													
									ARP_DST_PHY_ADDR[23:16]     <= IN_DATA;                                            			        													
							end                                                                                   			       													
ARP_BYTE22_ST:				begin                                                                          			       													
									ARP_ST 						<= ARP_BYTE23_ST;                                                     			      													
									ARP_DST_PHY_ADDR[15:8]	    <= IN_DATA;                                            			        													
							end                                                                                   			       													
ARP_BYTE23_ST:				begin                                                                          			      													
									ARP_ST 						<= ARP_BYTE24_ST;                                                     			      													
									ARP_DST_PHY_ADDR[7:0]	    <= IN_DATA;                                            			        													
							end        
// Прием даных 	ARP_DST_IP													                                                                          			       													
ARP_BYTE24_ST:				begin                                                                          			      													
									ARP_ST 						<= ARP_BYTE25_ST;                                                     			      													
									ARP_DST_IP[31:24]			<= IN_DATA;                                            			         													
							end                                                                                             													
ARP_BYTE25_ST:				begin                                                                          			      													
									ARP_ST 						<= ARP_BYTE26_ST;                                                     			    													
									ARP_DST_IP[23:16]			<= IN_DATA;                                            			    													
							end                                                                                   			       													
ARP_BYTE26_ST:				begin                                                                                   													
									ARP_ST						<= ARP_BYTE27_ST;                                                          													
									ARP_DST_IP[15:8]			<= IN_DATA; 		                                                 													
							end                                                                                             													
ARP_BYTE27_ST:				begin                                                                                   																	
							     	ARP_ST						<= ARP_REQUEST_ST;                                                          																	
									ARP_DST_IP[7:0]				<= IN_DATA; 		                                                 																	
							end                                                                                             																	
ARP_REQUEST_ST:			if (ARP_DST_IP == HTGv6_IP_ADDR)
							begin
							 if (ARP_MESS_TYPE == `ARP_REQUEST) 
									begin     
									   ARP_ST				    <= ARP_DONE_ST;
									   ARP_TYPE                 <= `ARP_TYPE_MES;
									   ARP_HEADER               <= {ARP_DST_IP,ARP_DST_PHY_ADDR,ARP_SRC_IP,ARP_SRC_PHY_ADDR,ARP_MESS_TYPE,ARP_PROT_ADDR_LEN,ARP_HARDW_ADDR_LEN,ARP_PROT_TYPE,ARP_HARDW_TYPE};  
				    				end         
						     else if (ARP_MESS_TYPE == `RARP_REQUEST) 
						     	     begin     
                                	   ARP_ST				    <= ARP_DONE_ST;
                             		   ARP_TYPE                 <= `RARP_TYPE_MES;
                             		   ARP_HEADER               <= {ARP_DST_IP,ARP_DST_PHY_ADDR,ARP_SRC_IP,ARP_SRC_PHY_ADDR,ARP_MESS_TYPE,ARP_PROT_ADDR_LEN,ARP_HARDW_ADDR_LEN,ARP_PROT_TYPE,ARP_HARDW_TYPE};  
                                 	 end
						     else 	      
									begin	
									   ARP_ST					<= ARP_DONE_ST;
									   ARP_TYPE                 <= `UNSUPPORTED_TYPE_MES;
									   ARP_HEADER               <= 224'b0;   
									end
							end
    					else	
    					   begin
    						   ARP_ST				    <= ARP_DONE_ST;
    						   ARP_TYPE                 <= `UNSUPPORTED_TYPE_MES;
    					       ARP_HEADER               <= ARP_HEADER;              
    					   end	                                               			

ARP_DONE_ST:            begin   		
				    					ARP_DONE				<= 1'b1;
				    					ARP_HEADER              <= ARP_HEADER;
										ARP_ST 					<= ARP_BYTE0_ST;
						end					
default:
						begin
						  ARP_ST 					      <= ARP_BYTE0_ST;
                          ARP_HEADER                      <= ARP_HEADER;  
                          ARP_TYPE                        <= ARP_TYPE;
                          ARP_DONE						  <= 1'b0;
                           
                    								
						  ARP_HARDW_TYPE 			      <= 16'b0;
                          ARP_PROT_TYPE   				  <= 16'b0;
                          ARP_HARDW_ADDR_LEN	          <= 8'b0;
                          ARP_PROT_ADDR_LEN		          <= 8'b0;
						  ARP_MESS_TYPE                   <= 16'b0;
                          ARP_SRC_PHY_ADDR                <= 48'b0;		 
                          ARP_SRC_IP                      <= 32'b0;
						  ARP_DST_PHY_ADDR			      <= 48'b0;
						  ARP_DST_IP					  <= 32'b0;
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
	    
	    .TRIG0			({ARP_HEADER[54:0],ARP_ST,ARP_TYPE,ARP_DONE,ARP_EN}), // IN BUS [63:0]
	    .TRIG1			({ARP_HEADER[8*8+55-1:55]}) // IN BUS [63:0]
	);
*/
endmodule
