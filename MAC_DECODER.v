`timescale 1ns/1ps
/*
Декодер заголовка МАС
*/

/*
MAC_DECODER MAC_DECODER_inst	
(
.RST					(),
.CLK					(),

.IN_PACKET_DATA			(),
.IN_PACKET_VLD			(),
// MAC данные
.MAC_HEADER             (), // [14*8-1:0]	
.MESS_TYPE              (),
.MAC_DONE               (),	
// Сигналы управления декодерами верхних уровней ARP и IP  
.ARP_DECODER_EN			(),
.ARP_DONE				(),
.IP_DECODER_EN			(),
.IP_DONE			    ()
);
*/

/*
Декодер МАС уровня принимаемых пакетов разбирает на части МАС-заголовок принятого пакета и управляет декодерами нижних уровней IP и ARP
 Если принято сообщение с чужим адресом, то декодер завершает работу и передает об этом сигнал приемнику, который в свою очередь мгновенно очищает свою память и готовится принимать новый пакет
 О том, что принято сообщение с чужим адресом МАС декодеру могут сообщить так же декодеры IP и ARP. Проделываются действия, описанные в предыдущей строке        

После полного принятия пакета декодер выдает сигнал валидности заголовков принятого пакета и сами значения заголовков.

*/


`define BROADCAST_ADDR 	48'hFF_FF_FF_FF_FF_FF
`define ARP_TYPE 	16'h0806
`define RARP_TYPE   16'h8035
`define IP_TYPE 	16'h0800

`define UNSUPPORTED_TYPE_MES 2'b00
`define ARP_TYPE_MES         2'b01
`define IP_TYPE_MES          2'b10

module MAC_DECODER
#(
parameter HTGv6_MAC_ADDR = 48'h00_0A_35_00_00_01
)
(
input 					RST,
input 					CLK,
input 		[7:0]		IN_DATA,
input 					IN_DATA_VLD,

input      [1:0]        ARP_TYPE,
input      [1:0]        IP_TYPE,

output reg [14*8-1:0]   MAC_HEADER,	
output reg [3:0]        MESS_TYPE,  // MESS_TYPE [1:0] 2'b00 - необрабатываемый далее тип запроса, 2'b01 - ARP запрос, 2'b10 - IP запрос. 
                                    // Если мы приняли запрос, который не будем далее обрабатывать например потому что при приеме UDP выяснилось, что порт не наш, 
                                    // то мы должны сообщить приемнику, что прием сообщения завершен с помощью сигнала MAC_DONE, чтобы он очистил буфер, 
                                    // но контроллер , через сигнал MESS_TYPE[1:0]должен знать, что заголовки данного сообщения принимать не надо ,
                                    // и, соответственно, ставить его в очередь обработки тоже не надо.  
                                     
output reg              MAC_DONE,	// Если параметры принятого собщения нам не подходят, то нет смысла принимать его дальше. Сбрасываем память входного буффера и можем принимать новое сообщение		

// Сигналы управления декодерами верхних уровней ARP и IP
output 					ARP_DECODER_EN,
output 					IP_DECODER_EN,
input 					ARP_DONE,
input 					IP_DONE
);
// Точно известно, что любой TCP/IP пакет несет в себе 14 байт данных заголовка MAC уровня 
localparam MAC_BYTE0_ST 			= 5'b00001;  // Прием данных пакета
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
localparam MAC_ARP_IP_EN_ST 		= 5'b01000;   // Включение декодеров ARP,RARP и IP
localparam MAC_WAIT_ARP_IP_DONE_ST 	= 5'b11000;   // Ожидание завершения их работы 
localparam MAC_DONE_ST 				= 5'b10000;   // Состояние окончания приема данных. Сообщаем контроллеру, что мы окончили прием пакета и сообщаем ему заголовки этого пакета

// MAC данные
reg [47:0]  MAC_SRC_ADDR_reg;
reg [47:0]  MAC_SRC_ADDR;
reg [47:0] 	MAC_DEST_ADDR;	
reg [15:0]  MAC_PROTOCOL_TYPE;			

(* fsm_encoding = "gray" *)
reg [4:0]  MAC_ST; 
reg [12:0]  WAIT_CNT;

always @(posedge CLK)						// Прием MAC данных от источника
if (RST)		
begin
	MAC_ST 					<= MAC_BYTE0_ST;
	
	MAC_SRC_ADDR_reg        <= 48'b0;
	MAC_SRC_ADDR            <= 48'b0;
	MAC_DEST_ADDR 			<= 48'b0;
	MAC_PROTOCOL_TYPE		<= 16'b0;

	MAC_HEADER              <= 112'b0;
	MESS_TYPE               <= 4'b0;
	MAC_DONE                <= 1'b0;
end																		
else 
(* parallel_case *)(* full_case *)
case (MAC_ST)
// Прием даных DESTINATION ADDRESS
MAC_BYTE0_ST:			begin
                            MAC_DONE <= 1'b0;	
                            if (IN_DATA_VLD)	
								begin
									MAC_ST 						<= MAC_BYTE1_ST;
									MAC_DEST_ADDR[47:40]		<= IN_DATA;
								end
							else 					
								begin
									MAC_ST 						<= MAC_BYTE0_ST;
									MAC_DEST_ADDR[47:40]		<= 8'b0;
								end
						end		
MAC_BYTE1_ST:				begin
									MAC_ST 						<= MAC_BYTE2_ST;
									MAC_DEST_ADDR[39:32]		<= IN_DATA;
							end
MAC_BYTE2_ST:				begin                                                                          													
									MAC_ST 						<= MAC_BYTE3_ST;                                                     														
									MAC_DEST_ADDR[31:24]		<= IN_DATA;                                            														
							end                              
MAC_BYTE3_ST:				begin                                                                          
									MAC_ST 						<= MAC_BYTE4_ST;                                                     
									MAC_DEST_ADDR[23:16]		<= IN_DATA;                                            
							end                                                                                   
MAC_BYTE4_ST:				begin                                                                          
									MAC_ST 						<= MAC_BYTE5_ST;                                                     
									MAC_DEST_ADDR[15:8]		    <= IN_DATA;                                            
						    end                                                                                   
MAC_BYTE5_ST:				begin                                                                          
									MAC_ST 					 	<= MAC_BYTE6_ST;                                                     
									MAC_DEST_ADDR[7:0]		    <= IN_DATA;                                            
							end    
// Прием даных SOURCE ADDRESS													                                                                               
MAC_BYTE6_ST:				begin                                                                          
									MAC_ST 						<= MAC_BYTE7_ST;                                                     													                                                     														
									MAC_SRC_ADDR_reg[47:40]     <= IN_DATA;                                            														
						    end                                                                                   			
MAC_BYTE7_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE8_ST;                                                     			
									MAC_SRC_ADDR_reg[39:32]	   	<= IN_DATA;                                            			
							end                                                                                   			
MAC_BYTE8_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE9_ST;                                                     			
									MAC_SRC_ADDR_reg[31:24]	    <= IN_DATA;                                            			
							end                                                                                   			
MAC_BYTE9_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE10_ST;                                                     			
									MAC_SRC_ADDR_reg[23:16]	   	<= IN_DATA;                                            			
							end                                                                                   			
MAC_BYTE10_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE11_ST;                                                     			
									MAC_SRC_ADDR_reg[15:8]	   	<= IN_DATA;                                            			
							end                                                                                   			
MAC_BYTE11_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE12_ST;                                                     			
									MAC_SRC_ADDR_reg[7:0]	    <= IN_DATA;                                            			
							end   
// Прием даных PROTOCOL TYPE													
MAC_BYTE12_ST:				begin                                                                          			
									MAC_ST 						<= MAC_BYTE13_ST;                                                     			
									MAC_PROTOCOL_TYPE[15:8]		<= IN_DATA;                                            			
							end                                                                                   			
MAC_BYTE13_ST:				begin
									MAC_ST						<= MAC_ARP_IP_EN_ST;
									MAC_PROTOCOL_TYPE[7:0]		<= IN_DATA; 		
							end
MAC_ARP_IP_EN_ST:			if      (((MAC_PROTOCOL_TYPE == `ARP_TYPE)||(MAC_PROTOCOL_TYPE == `RARP_TYPE))&&((MAC_DEST_ADDR == `BROADCAST_ADDR)||(MAC_DEST_ADDR == HTGv6_MAC_ADDR)))		
                                begin        
                                    MESS_TYPE[1:0]  <= `ARP_TYPE_MES;
                                    MAC_ST 	        <= MAC_WAIT_ARP_IP_DONE_ST;                                          
                                    MAC_SRC_ADDR    <= MAC_SRC_ADDR_reg;
                                end    
							else if ((MAC_PROTOCOL_TYPE == `IP_TYPE)&&(MAC_DEST_ADDR == HTGv6_MAC_ADDR))	// Широковещательные IP не принимаем, потому фильтруем МАС	
								begin        
								    MESS_TYPE[1:0]  <= `IP_TYPE_MES;
                                    MAC_ST 	        <= MAC_WAIT_ARP_IP_DONE_ST;                                          
                                    MAC_SRC_ADDR    <= MAC_SRC_ADDR_reg;
                                end 
					       	else 
					       	   begin
					       	       //MAC_DONE <= 1'b1;
					       		   MESS_TYPE[1:0]  <= `UNSUPPORTED_TYPE_MES;      // 2'b00 cообщает контроллеру, что этот запрос обрабатывать не надо
					       		   MAC_ST 	<= MAC_DONE_ST;       // В случае если параметры принимаемого сообщения нам не подходят, то ждем пока оно кончится
					       	   end	                        
MAC_WAIT_ARP_IP_DONE_ST:	if (WAIT_CNT <= 13'd1700)            // Если нет ответа о принятии сообщения. Размеры паузы превышает возможный максимальный размер IP пакета 1500 байт
                                begin
                                    if (MESS_TYPE[1:0] == `ARP_TYPE_MES)
                                        begin
                                            if (ARP_DONE)
                                                begin
                                                    MAC_HEADER      <= {MAC_PROTOCOL_TYPE,MAC_SRC_ADDR,MAC_DEST_ADDR};
                                                    MAC_ST          <= MAC_DONE_ST;
                                                    MESS_TYPE[3:2]  <=  ARP_TYPE;
                                                    if (ARP_TYPE != 2'b00)   MESS_TYPE[1:0]  <=  MESS_TYPE[1:0];
                                                    else                     MESS_TYPE[1:0]  <=  `UNSUPPORTED_TYPE_MES;
                                                end
                                            else 
                                                begin
                                                    MAC_HEADER      <= MAC_HEADER;
                                                    MAC_ST          <= MAC_ST;
                                                    MESS_TYPE[1:0]  <= MESS_TYPE[1:0];
                                                    MESS_TYPE[3:2]  <= MESS_TYPE[3:2];  
                                                end    
                                        end
                                    else if (MESS_TYPE[1:0] == `IP_TYPE_MES)
                                        begin
                                            if (IP_DONE)
                                                begin
                                                    MAC_HEADER      <= {MAC_PROTOCOL_TYPE,MAC_SRC_ADDR,MAC_DEST_ADDR};
                                                    MAC_ST          <= MAC_DONE_ST;
                                                    MESS_TYPE[3:2]  <= IP_TYPE;
                                                    if (IP_TYPE != 2'b00)   MESS_TYPE[1:0]  <=  MESS_TYPE[1:0];
                                                    else                    MESS_TYPE[1:0]  <=  `UNSUPPORTED_TYPE_MES;
                                                end
                                            else
                                                begin
                                                    MAC_HEADER      <= MAC_HEADER;
                                                    MAC_ST          <= MAC_ST;
                                                    MESS_TYPE[1:0]  <= MESS_TYPE[1:0];
                                                    MESS_TYPE[3:2]  <= MESS_TYPE[3:2]; 
                                                end
                                        end            
                                    else
                                        begin
                                                    MAC_HEADER      <= MAC_HEADER;
                                                    MAC_ST          <= MAC_ST;
                                                    MESS_TYPE[1:0]  <= MESS_TYPE[1:0];
                                                    MESS_TYPE[3:2]  <= MESS_TYPE[3:2];
                                        end        
                                end                                    
							else        
									begin
                                            //MAC_DONE        <= 1'b1;
                                            MESS_TYPE[1:0]  <=  `UNSUPPORTED_TYPE_MES;
                                            MAC_HEADER      <= MAC_HEADER;
							                MAC_ST          <= MAC_DONE_ST;
							        end 
							                
MAC_DONE_ST:                begin                
                                 
                                 MESS_TYPE      <= MESS_TYPE;
                                 MAC_HEADER     <= MAC_HEADER;  
                                 if (IN_DATA_VLD)
                                    begin
                                         MAC_ST         <= MAC_DONE_ST;
                                    end
                                 else         
                                    begin
                                         MAC_DONE       <= 1'b1;
                                         MAC_ST         <= MAC_BYTE0_ST;
                                    end 
                            end
default:    				begin
								MAC_ST 						<= MAC_ST;
								
								MAC_SRC_ADDR_reg            <= 48'b0;
								MAC_SRC_ADDR                <= 48'b0;
								MAC_DEST_ADDR 				<= 48'b0;
								MAC_PROTOCOL_TYPE	      	<= 16'b0;
								
								MAC_HEADER                  <= 112'b0;
                                MAC_DONE                    <= 1'b0;
			     			end
endcase

assign		ARP_DECODER_EN = ((MAC_ST == MAC_ARP_IP_EN_ST)&&(MAC_PROTOCOL_TYPE == `ARP_TYPE)&&((MAC_DEST_ADDR == `BROADCAST_ADDR)||(MAC_DEST_ADDR == HTGv6_MAC_ADDR)))?1'b1:1'b0;
assign		IP_DECODER_EN  = ((MAC_ST == MAC_ARP_IP_EN_ST)&&(MAC_PROTOCOL_TYPE == `IP_TYPE) &&(MAC_DEST_ADDR == HTGv6_MAC_ADDR)) ?1'b1:1'b0;


always @(posedge CLK or posedge RST)
if (RST)                                        WAIT_CNT <= 13'd0;
else if (MAC_ST == MAC_WAIT_ARP_IP_DONE_ST)     WAIT_CNT <= WAIT_CNT + 1'b1;
else                                            WAIT_CNT <= 13'd0;
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
	    
	    .TRIG0			({MAC_SRC_ADDR[45:0],IN_DATA,MAC_ST,ARP_TYPE,ARP_DONE,ARP_DECODER_EN,IN_DATA_VLD}), // IN BUS [63:0]
	    .TRIG1			({MAC_HEADER[58:0],MESS_TYPE,MAC_DONE}) // IN BUS [63:0]
	);
*/
endmodule