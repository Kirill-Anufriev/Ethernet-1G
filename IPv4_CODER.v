`timescale 1ns/1ps

/*
Декодер принимаемых IPv4 сообщений
*/

/*
IPv4_CODER    IPv4_CODER_inst
#(
.HTGv6_IP_ADDR 	        (),
.HTGv6_MAC_ADDR 		(),
.HTGv6_UDP_PORT      	()
)
(
.RST                             	(),
.CLK                            		(),
.EN                              		(),

.IP_VER                         	(),		// [3:0]
.IP_HDR_LENGTH          	(),		// [3:0]
.IP_DIFF_SERV_FIELD    	(),		// [7:0] 
.IP_TOTAL_LENGTH       	(),		// [15:0]
.IP_IDENTIFICATION      (),		// [15:0]
.IP_FRAGMENT_FLAGS  	(),		// [2:0]
.IP_FRAGMENT_OFFSET	(),		// [12:0]
.IP_TIME_TO_LIVE         	(),		// [7:0]
.IP_PROTOCOL              	(),		// [7:0]
.IP_SRC_IP_ADDR          	(),    	// [31:0]
.IP_DST_IP_ADDR        	(),		// [31:0]

// ICMP данные
.ICMP_TX_CLK				(),
.ICMP_TX_DATA_REQ		(),
.ICMP_TX_DATA				(),		// [63:0]

.ICMP_REP_REQUEST		(),     // Запрос на формирование ответного сообщения к принятому ICMP (Reply)
.ICMP_TYPE						(),		// [7:0]
.ICMP_CODE					(),		// [7:0]
.ICMP_DATA_CHECKSUM(),	// [15:0]
.ICMP_IDENTIFIER			(),		// [15:0]
.ICMP_SEQUENCER			(),		// [15:0]

// IP данные
.IPv4_DONE                		()
);
*/

`define ICMP_PROTOCOL_TYPE  16'h0001
`define UDP_PROTOCOL_TYPE    16'h0011

`define ICMP_TYPE_MES        2'b01
`define UDP_TYPE_MES         2'b10
`define TCP_TYPE_MES         2'b11

module IP_CODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01,
parameter HTGv6_UDP_PORT    = 16'h00_01
)
(
input 		RST,
input 		CLK,

input [20*8-1:0]   IP_HEADER,
input [8*8+4-1:0]  ICMP_HEADER,
input [8*8-1:0]    UDP_HEADER,

input           IP_EN,
input [1:0]     IP_TYPE,
output reg	  	IP_DONE,
output reg [7:0]IP_OUT_DATA,

// ICMP данные
output 		  	ICMP_TX_DATA_REQ,
input [7:0] 	ICMP_TX_DATA,
input 			ICMP_TX_DATA_VLD,
// UDP данные
output 			UDP_DATA_REQUEST,		// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные
input [15:0]	UDP_PACKET_NUMBER,	// Порядковый номер передаваемой посылки для IP
input [15:0] 	UDP_DATA_LENGTH,		// Количество передавамых байт
input [15:0]	UDP_DATA_CHECKSUM,	// Контрольная сумма данных
input [7:0]		DATA_FROM_USER,											// [7:0]
input 			DATA_FROM_USER_VLD
);



localparam IP_BYTE0_ST  		= 5'b00001;
localparam IP_BYTE1_ST  		= 5'b00011;
localparam IP_BYTE2_ST  		= 5'b00010;
localparam IP_BYTE3_ST  		= 5'b00110;
localparam IP_BYTE4_ST  		= 5'b00111;
localparam IP_BYTE5_ST  		= 5'b00101;
localparam IP_BYTE6_ST  		= 5'b00100;
localparam IP_BYTE7_ST  		= 5'b01100;
localparam IP_BYTE8_ST  		= 5'b01101;  
localparam IP_BYTE9_ST  		= 5'b01111; 
localparam IP_BYTE10_ST  		= 5'b01110;
localparam IP_BYTE11_ST  		= 5'b01010;
localparam IP_BYTE12_ST  		= 5'b01011;
localparam IP_BYTE13_ST  		= 5'b01001;
localparam IP_BYTE14_ST  		= 5'b01000;
localparam IP_BYTE15_ST  		= 5'b11000;
localparam IP_BYTE16_ST  		= 5'b11001;
localparam IP_BYTE17_ST  		= 5'b11011;
localparam IP_BYTE18_ST  		= 5'b11010;
localparam IP_BYTE19_ST  		= 5'b11110;
localparam IP_ICMP_EN_ST 	    = 5'b11111;
localparam IP_UDP_EN_ST  		= 5'b11101;
localparam IP_WAIT_ICMP_UDP_DONE_ST = 5'b10101;
localparam IP_DONE_ST   	 	= 5'b10001;

wire [3:0]   IP_VER;					      	// Для IPv4 значение 4
wire [3:0]   IP_HDR_LENGTH;				      	// Измеряется в количестве 32-х битных слов (обычно 20 байт = 5 DW, максимум 60 байт = 15 DW)
wire [7:0]   IP_DIFF_SERV_FIELD;		      	// Тип сервиса (Байт дифференцированного обслуживания) 
wire [15:0]  IP_TOTAL_LENGTH;
wire [15:0]  IP_IDENTIFICATION;
wire [2:0]   IP_FRAGMENT_FLAGS;	    	       	// [1] говорит маршрутизатору можно фрагментировать пакет или нет,  [2] фит сообщает о том, последний это пакет из полного состава данных или нет
wire [12:0]  IP_FRAGMENT_OFFSET;		      	// Используется при сборке/разборке фрагментов пакета. Кратно 8 байтам
wire [7:0]   IP_TIME_TO_LIVE;		    		// Время жизни пакета. стандартно 64 или 128  
wire [7:0]   IP_PROTOCOL;
/* CHECKSUM */
reg  [19:0]  CHECKSUM;                          //
reg  [15:0]  IP_OUT_CHECKSUM;                   // Все, что относится к контрольной сумме. Считается в этом модуле
reg  [19:0]  PSEUDO_HEADER_CHECKSUM;            //
reg  [15:0]  UDP_PSEUDO_HEADER_CHECKSUM;        //
/* -------- */
wire [31:0]  IP_DST_IP_ADDR;
wire [31:0]  IP_SRC_IP_ADDR;		        	// IP адрес источника сообщения
wire [15:0]  IP_UDP_TOTAL_LENGTH;

(* fsm_encoding = "gray" *)
reg [4:0]   IP_ST;

reg  ICMP_EN;        // Запрос к модулям дальнейшей обработки принятого сообщения
reg  UDP_EN;         //
wire ICMP_DONE; 
wire UDP_DONE;

wire [7:0]  ICMP_OUT_DATA;
wire [7:0]  UDP_OUT_DATA;
wire        UDP_REQUEST; // В дальнейшем переделать во вход модуля

assign IP_VER 				= 4'h4;
assign IP_HDR_LENGTH		= 4'h5;
assign IP_DIFF_SERV_FIELD	= 8'd0;
assign IP_TOTAL_LENGTH      = IP_HEADER[31:16];
assign IP_IDENTIFICATION    = IP_HEADER[47:32];
assign IP_FRAGMENT_FLAGS	= 3'd0;
assign IP_FRAGMENT_OFFSET	= 13'd0;
assign IP_TIME_TO_LIVE		= 8'd64;
assign IP_PROTOCOL          = IP_HEADER[79:72];
/******************** Расчет контрольной суммы ***************************/
always @(posedge CLK or posedge RST)
if (RST)	
        begin					
                 CHECKSUM <= 0;
                 PSEUDO_HEADER_CHECKSUM <= 0;
        end          
else if (IP_EN)
    begin
        case (IP_TYPE)
        `ICMP_TYPE_MES:
            begin
                CHECKSUM                <= {IP_VER,IP_HDR_LENGTH,IP_DIFF_SERV_FIELD} + IP_TOTAL_LENGTH + IP_IDENTIFICATION 
                                            /**/ + {IP_FRAGMENT_FLAGS,IP_FRAGMENT_OFFSET} +{IP_TIME_TO_LIVE,IP_PROTOCOL} + IP_SRC_IP_ADDR[31:16] 
                                            /**/ + IP_SRC_IP_ADDR[15:0] + IP_DST_IP_ADDR[31:16] + IP_DST_IP_ADDR[15:0];
                PSEUDO_HEADER_CHECKSUM  <= PSEUDO_HEADER_CHECKSUM;
            end
        `UDP_TYPE_MES:
            begin
                 CHECKSUM               <= {IP_VER,IP_HDR_LENGTH,IP_DIFF_SERV_FIELD} + IP_UDP_TOTAL_LENGTH + UDP_PACKET_NUMBER 
                                            /**/ + {IP_FRAGMENT_FLAGS,IP_FRAGMENT_OFFSET} +{IP_TIME_TO_LIVE,IP_PROTOCOL} + IP_SRC_IP_ADDR[31:16] 
                                            /**/ + IP_SRC_IP_ADDR[15:0] + IP_DST_IP_ADDR[31:16] + IP_DST_IP_ADDR[15:0];
                 PSEUDO_HEADER_CHECKSUM <= (IP_UDP_TOTAL_LENGTH-{10'b0,IP_HDR_LENGTH,2'b0})+{8'b0,IP_PROTOCOL} 
                                            /**/ + IP_SRC_IP_ADDR[31:16]+ IP_SRC_IP_ADDR[15:0] + IP_DST_IP_ADDR[31:16] + IP_DST_IP_ADDR[15:0];
            end
        default:
            begin
                CHECKSUM                <= CHECKSUM;
                PSEUDO_HEADER_CHECKSUM  <= PSEUDO_HEADER_CHECKSUM;
            end
        endcase    
    end
else if (IP_DONE)        
    begin
                CHECKSUM                <= 0;
                PSEUDO_HEADER_CHECKSUM  <= 0;
    end    
else 
    begin
                CHECKSUM                <= CHECKSUM;
                PSEUDO_HEADER_CHECKSUM  <= PSEUDO_HEADER_CHECKSUM;
    end    
           

always @(posedge CLK or posedge RST)
if (RST)
    begin
        IP_OUT_CHECKSUM              <= 20'b0;
        UDP_PSEUDO_HEADER_CHECKSUM   <= 20'b0;
    end
else
    begin
        IP_OUT_CHECKSUM              <= ~(CHECKSUM[15:0] + {12'b0,CHECKSUM[19:16]});
        UDP_PSEUDO_HEADER_CHECKSUM   <= PSEUDO_HEADER_CHECKSUM[15:0] + {12'b0,PSEUDO_HEADER_CHECKSUM[19:16]};
    end

/**************************************************************************/

assign IP_SRC_IP_ADDR		= HTGv6_IP_ADDR;
assign IP_DST_IP_ADDR       = IP_HEADER[20*8-33:20*8-32-32];
assign IP_UDP_TOTAL_LENGTH  = {9'b0,IP_HDR_LENGTH,2'b0} /*Длина заголовка IP в байтах*/ +  16'd8/*Длина заголовка UDP в байтах*/ + UDP_DATA_LENGTH; // Объем передаваемыъх данных UDP

// Формирование заголовка MAC
always @(posedge CLK)						
if (RST)		
begin
	IP_ST 								<= IP_BYTE0_ST;
	IP_OUT_DATA						    <= 0;
	IP_DONE								<= 0;
	ICMP_EN								<= 0;
	UDP_EN								<= 0;  
end																		
else 
(* parallel_case *)(* full_case *)
case (IP_ST)
// Формирование даных IP_VER и IP_HDR_LENGTH
IP_BYTE0_ST:	if (IP_EN)
                    begin      
                        if (IP_TYPE == `ICMP_TYPE_MES)				
								begin					
										IP_DONE							<= 0;	
										IP_OUT_DATA						<= {IP_VER,IP_HDR_LENGTH};
										IP_ST 							<= IP_BYTE1_ST;
								end		
						else if (IP_TYPE == `UDP_TYPE_MES)						
								begin					
										IP_DONE							<= 0;	
										IP_OUT_DATA						<= {IP_VER,IP_HDR_LENGTH};
										IP_ST 							<= IP_BYTE1_ST;
								end
						else 
								begin					
										IP_DONE							<= 0;	
										IP_OUT_DATA						<= {IP_VER,IP_HDR_LENGTH};
										IP_ST 							<= IP_BYTE0_ST;
								end
					end
				else
				    begin
				        IP_DONE							<= 0;	
                    	IP_OUT_DATA						<= {IP_VER,IP_HDR_LENGTH};
                    	IP_ST 							<= IP_BYTE0_ST;
				    end				
// Формирование даных IP_DIFF_SERV_FIELD
IP_BYTE1_ST:								begin
															IP_ST 									<= IP_BYTE2_ST;
															IP_OUT_DATA						        <= IP_DIFF_SERV_FIELD;
													end
// Формирование даных IP_TOTAL_LENGTH													
IP_BYTE2_ST:								begin                                                                          													
															IP_ST 							  		<= IP_BYTE3_ST;   
															if (IP_TYPE == `ICMP_TYPE_MES) 		IP_OUT_DATA <= IP_TOTAL_LENGTH[15:8];       
															else if (IP_TYPE == `UDP_TYPE_MES)  IP_OUT_DATA <= IP_UDP_TOTAL_LENGTH[15:8];                                                           														
													end                              
IP_BYTE3_ST:								begin                                                                          
															IP_ST 									<= IP_BYTE4_ST;                                                     
															if (IP_TYPE == `ICMP_TYPE_MES) 		IP_OUT_DATA <= IP_TOTAL_LENGTH[7:0];       
															else if (IP_TYPE == `UDP_TYPE_MES)  IP_OUT_DATA <= IP_UDP_TOTAL_LENGTH[7:0];                                        
													end        
// Формирование даных IP_IDENTIFICATION													                                                                           
IP_BYTE4_ST:								begin                                                                          
															IP_ST 									<= IP_BYTE5_ST;                       
															if (IP_TYPE == `ICMP_TYPE_MES) 		 IP_OUT_DATA <= IP_IDENTIFICATION[15:8];       
															else if (IP_TYPE == `UDP_TYPE_MES)  IP_OUT_DATA <= UDP_PACKET_NUMBER[15:8];                              
													end                                                                                   
IP_BYTE5_ST:								begin                                                                          
															IP_ST 					   			    <= IP_BYTE6_ST;                                                     
															if (IP_TYPE == `ICMP_TYPE_MES) 		IP_OUT_DATA <= IP_IDENTIFICATION[7:0];       
															else if (IP_TYPE ==`UDP_TYPE_MES)   IP_OUT_DATA <= UDP_PACKET_NUMBER[7:0];                                        
													end    
// Формирование даных IP_FRAGMENT_FLAGS и IP_FRAGMENT_OFFSET												                                                                               
IP_BYTE6_ST:								begin                                                                          
															IP_ST 									<= IP_BYTE7_ST;                                                     													                                                     														
															IP_OUT_DATA						        <= {IP_FRAGMENT_FLAGS,IP_FRAGMENT_OFFSET[12:8]};                                           														
													end                                                                                   			
IP_BYTE7_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE8_ST;                                                     			
															IP_OUT_DATA						        <= IP_FRAGMENT_OFFSET[7:0];                                             			
													end             
//Формирование даных IP_TIME_TO_LIVE													                                                                      			
IP_BYTE8_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE9_ST;                                                     			
															IP_OUT_DATA						        <= IP_TIME_TO_LIVE;                                             			
													end       
//Формирование даных IP_PROTOCOL													                                                                            			
IP_BYTE9_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE10_ST;      
															if (IP_TYPE == `ICMP_TYPE_MES) 		 IP_OUT_DATA <= `ICMP_PROTOCOL_TYPE;       
															else if (IP_TYPE == `UDP_TYPE_MES)  IP_OUT_DATA <= `UDP_PROTOCOL_TYPE;   
													end      
//Формирование даных IP_OUT_CHECKSUM													                                                                             			
IP_BYTE10_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE11_ST;                                                     			
															IP_OUT_DATA						        <= IP_OUT_CHECKSUM[15:8];                                            			
													end
IP_BYTE11_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE12_ST;                                                     			
															IP_OUT_DATA						        <= IP_OUT_CHECKSUM[7:0];                                            			
													end   
//Формирование даных IP_SRC_IP_ADDR
IP_BYTE12_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE13_ST;                                                     			
															IP_OUT_DATA						        <= IP_SRC_IP_ADDR[31:24];                                           			
													end       
IP_BYTE13_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE14_ST;                                                     			
															IP_OUT_DATA						        <= IP_SRC_IP_ADDR[23:16];                                             			
													end                                                                                   			
IP_BYTE14_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE15_ST;                                                     			
															IP_OUT_DATA						        <= IP_SRC_IP_ADDR[15:8];                                             			
													end         
IP_BYTE15_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE16_ST;                                                     			
															IP_OUT_DATA						        <= IP_SRC_IP_ADDR[7:0];                                             			
													end                                                                                   			
//Формирование даных IP_DST_IP_ADDR	
IP_BYTE16_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE17_ST;                                                     			
															IP_OUT_DATA						        <= IP_DST_IP_ADDR[31:24];                                            			
													end                                                                                   			
IP_BYTE17_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE18_ST;                                                     			
															IP_OUT_DATA						        <= IP_DST_IP_ADDR[23:16];                                             			
													end   
IP_BYTE18_ST:								begin                                                                          			
															IP_ST 									<= IP_BYTE19_ST;                                                     			
															IP_OUT_DATA						        <= IP_DST_IP_ADDR[15:8];         
															if (IP_TYPE == `ICMP_TYPE_MES)	      ICMP_EN	<= 1;
															else if (IP_TYPE == `UDP_TYPE_MES)	  UDP_EN	<= 1;                                   			
													end 													                                                                            			
IP_BYTE19_ST:								begin						
															IP_OUT_DATA							    <= IP_DST_IP_ADDR[7:0];  
															ICMP_EN								    <= 0;
															UDP_EN								    <= 0;  
														if (IP_TYPE == `ICMP_TYPE_MES)			IP_ST	    <= IP_ICMP_EN_ST;
														else if (IP_TYPE == `UDP_TYPE_MES)	    IP_ST	    <= IP_UDP_EN_ST;
														else 							        IP_ST	    <= IP_DONE_ST;
													end
IP_ICMP_EN_ST:							begin
															IP_OUT_DATA						         <= ICMP_OUT_DATA;							
															IP_ST								     <= IP_WAIT_ICMP_UDP_DONE_ST;
													end		
IP_UDP_EN_ST:							begin
															IP_OUT_DATA						         <= UDP_OUT_DATA;							
															IP_ST								     <= IP_WAIT_ICMP_UDP_DONE_ST;
													end
IP_WAIT_ICMP_UDP_DONE_ST:	                        if 	(ICMP_DONE || UDP_DONE)	
															begin
																IP_ST 							     <= IP_DONE_ST;
																IP_OUT_DATA					         <= 0;
																IP_DONE 						     <= 1;
															end	
													else 
														begin
																IP_ST 				                 <= IP_WAIT_ICMP_UDP_DONE_ST;
															case (IP_TYPE)
																`ICMP_TYPE_MES:	IP_OUT_DATA		     <= ICMP_OUT_DATA;			
																`UDP_TYPE_MES:	IP_OUT_DATA		     <= UDP_OUT_DATA;	
																default:IP_OUT_DATA		             <= 0;		
															endcase
														end	
IP_DONE_ST:								begin	
															IP_DONE 							     <= 0;
															IP_ST	 							     <= IP_BYTE0_ST;
														end	
default:													
														begin
															IP_ST 								     <= IP_BYTE0_ST;
															IP_OUT_DATA						         <= 0;
														end
endcase   

 ICMP_CODER ICMP_CODER_inst
 (
 .RST        		(RST),
 .CLK       		(CLK),     							// RX_CLK

 .ICMP_DATA_REQ		(ICMP_TX_DATA_REQ),	// O
 .ICMP_IN_DATA     	(ICMP_TX_DATA),        				//  [63:0]
 .ICMP_IN_DATA_VLD	(ICMP_TX_DATA_VLD),
// ICMP данные
 .ICMP_EN   		(ICMP_EN),
 .ICMP_HEADER		(ICMP_HEADER),    				// [7:0]
 .ICMP_OUT_DATA		(ICMP_OUT_DATA),			// [63:0]
 .ICMP_DONE		    (ICMP_DONE)					// O
 );

assign ICMP_REP_DONE = ICMP_DONE;

UDP_CODER	
#(
.HTGv6_UDP_PORT     (HTGv6_UDP_PORT)
)
UDP_CODER_inst
(
.RST				(RST),
.CLK				(CLK),
.UDP_EN				(UDP_EN),
.UDP_HEADER         (UDP_HEADER),

.UDP_DONE			(UDP_DONE),

.IN_DATA			(DATA_FROM_USER),		// [7:0]
.IN_DATA_VLD		(DATA_FROM_USER_VLD),
.IN_DATA_LENGTH	    (UDP_DATA_LENGTH),
// UDP данные
.UDP_DATA_REQUEST   (UDP_DATA_REQUEST), // от формирователя UDP к памяти с данными

.UDP_DATA_CHECKSUM              (UDP_DATA_CHECKSUM),
.UDP_PSEUDO_HEADER_CHECKSUM     (UDP_PSEUDO_HEADER_CHECKSUM),       // Оказывается для расчета контрольной суммы UDP и TCP необходимо считать контрольную суму псевдозаголовка из состава заголовка IP
.UDP_DATA			(UDP_OUT_DATA) // [7:0]
    );

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
	    
	    .TRIG0			({6'b0,IP_OUT_CHECKSUM,PSEUDO_HEADER_CHECKSUM,CHECKSUM,IP_DONE,IP_EN}), // IN BUS [63:0]
	    .TRIG1			({64'b0}) // IN BUS [63:0]
	);
*/

endmodule