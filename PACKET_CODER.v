`timescale 1ns / 1ps

/*
PACKET_CODER		
#(
.HTGv6_IP_ADDR						(HTGv6_IP_ADDR),
.HTGv6_MAC_ADDR 					(HTGv6_MAC_ADDR)
)
PACKET_CODER_inst
(
.RST											(),
.CLK											(),

.OUT_PACKET_DATA					(),					// [63:0]
.OUT_PACKET_VLD					(),

// MAC данные
.MAC_DEST_ADDR						(),					// [47:0]
.MAC_SRC_ADDR						(),					// [47:0]
.MAC_PROTOCOL_TYPE				(),					// [15:0]
// ARP данные
.ARP_REQUEST							(),					// Если приняли ARP запрос, то после его обработки отправляем запрос к передающему модулю на отправку ответного ARP пакета

.ARP_HARDW_TYPE					(),					// [15:0] 
.ARP_PROT_TYPE						(),					// [15:0]
.ARP_HARDW_ADDR_LEN			(),					// [7:0]
.ARP_PROT_ADDR_LEN				(),					// [7:0]	
.ARP_TYPE								(),					// [15:0]
.ARP_SRC_PHY_ADDR				(),					// [47:0]
.ARP_SRC_IP								(),					// [32:0]
.ARP_DST_PHY_ADDR				(),					// [47:0]
.ARP_DST_IP								(),					// [32:0]
// IP данные
.IP_VER										(),					// [3:0]
.IP_HDR_LENGTH						(),					// [3:0]
.IP_DIFF_SERV_FIELD				(),					// [7:0]
.IP_TOTAL_LENGTH					(),					// [15:0]
.IP_IDENTIFICATION					(),					// [15:0]
.IP_FRAGMENT_FLAGS				(),					// [2:0]
.IP_FRAGMENT_OFFSET				(),					// [12:0]
.IP_TIME_TO_LIVE						(),					// [7:0] 
.IP_PROTOCOL							(),					// [7:0]
.IP_CHECKSUM							(),					// [15:0]
.IP_SRC_IP_ADDR						(),					// [31:0]
.IP_DEST_IP_ADDR					(),					// [31:0]
// ICMP данные
.ICMP_REP_REQUEST				(), 
.ICMP_TX_CLK						(),
.ICMP_TX_DATA_REQ				(),
.ICMP_TX_DATA						(),		//[63:0]
.ICMP_TYPE								(),//[7:0]
.ICMP_CODE							(),//[7:0]
.ICMP_DATA_CHECKSUM		(),//[15:0]
.ICMP_IDENTIFIER					(),//[15:0]
.ICMP_SEQUENCER					(),//[15:0]
// Полезные данные
.DATA_FROM_USER					(),					// [63:0]
.DATA_FROM_USER_VLD			()
);
*/

module PACKET_CODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01,
parameter HTGv6_UDP_PORT    = 16'h00_01
)
	(
	input 				RST,
	input 				CLK,
	
	input               MESS_TYPE_VLD,     // Валидность запроса
	input [3:0]         MESS_TYPE,         // Тип запрашиваемого сообщения	
	output 				MESS_DONE,
		
	input [14*8-1:0] 	MAC_HEADER,						
	input [28*8-1:0] 	ARP_HEADER,							
	input [20*8-1:0] 	IP_HEADER,			
    input [8*8+4-1:0]   ICMP_HEADER,
    input [8*8-1:0]     UDP_HEADER,
	//ICMP данные
	output 				ICMP_TX_DATA_REQ,
	input [7:0]			ICMP_TX_DATA,
	input 				ICMP_TX_DATA_VLD,
// UDP данные для передачи
	output 				UDP_DATA_REQUEST,	// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные
	input [7:0]			DATA_FROM_USER,		// [7:0]
	input 				DATA_FROM_USER_VLD,
    input [15:0]        UDP_PACKET_NUMBER,	// Порядковый номер передаваемой посылки для IP
    input [15:0]        UDP_DATA_LENGTH,	// Количество передавамых байт
    input [15:0]        UDP_DATA_CHECKSUM,	// Контрольная сумма данных
    
    output [7:0]		OUT_PACKET_DATA,
    output 				OUT_PACKET_VLD
    );
 
 wire  					ARP_EN;
 wire [1:0]             ARP_TYPE; 
 wire [7:0] 			ARP_DATA;
 wire  					ARP_DONE;
 
 wire                   IP_EN;
 wire [1:0]             IP_TYPE;
 wire [7:0]   			IP_DATA;
 wire 					IP_DONE;
 ///////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////// Формирователь Заголовков MAC /////////////////////////////
 ///////////////////////////////////////////////////////////////////////////////////////////////////////
    MAC_CODER	
    #(
    .HTGv6_MAC_ADDR 		(HTGv6_MAC_ADDR)
    )
    MAC_CODER_inst
    (
    .RST					(RST),
    .CLK    				(CLK),
    
    .REQ_TYPE_VLD           (MESS_TYPE_VLD),
    .REQ_TYPE               (MESS_TYPE),
    .REQ_DONE               (MESS_DONE),
    
    .MAC_HEADER             (MAC_HEADER),

    .ARP_EN					(ARP_EN),
    .ARP_TYPE               (ARP_TYPE),
    .ARP_DATA               (ARP_DATA), 
    .ARP_DONE				(ARP_DONE),
    
    .IP_EN  				(IP_EN),
    .IP_TYPE                (IP_TYPE),
    .IP_DATA                (IP_DATA),
    .IP_DONE				(IP_DONE),
    
    //////////////////////////////////////////////////////////////////////////////
    .OUT_DATA				(OUT_PACKET_DATA),
    .OUT_DATA_VLD			(OUT_PACKET_VLD)
    );
 
 ///////////////////////////////////////////////////////////////////////////////////////////////////////
 /////////////////////////////// Формирователь  ARP //////////////////////////////////////
 ///////////////////////////////////////////////////////////////////////////////////////////////////////
  ARP_CODER	 
 #(
 .HTGv6_IP_ADDR			(HTGv6_IP_ADDR),
 .HTGv6_MAC_ADDR    	(HTGv6_MAC_ADDR)
 )
 ARP_CODER_inst
 (
 .RST					(RST),
 .CLK		     		(CLK),
 
 .MESS_DONE             (MESS_DONE),
 
 .ARP_HEADER			(ARP_HEADER),
 
 .ARP_EN				(ARP_EN),
 .ARP_TYPE              (ARP_TYPE), 							
 .ARP_OUT_DATA		    (ARP_DATA),
 .ARP_DONE				(ARP_DONE)
 );
      
 ///////////////////////////////////////////////////////////////////////////////////////////////////////
 /////////////////////////////// Формирователь  IP //////////////////////////////////////
 ///////////////////////////////////////////////////////////////////////////////////////////////////////     
  IP_CODER    
 #(
 .HTGv6_IP_ADDR 	       	(HTGv6_IP_ADDR),
 .HTGv6_MAC_ADDR 			(HTGv6_MAC_ADDR),
 .HTGv6_UDP_PORT      		(HTGv6_UDP_PORT)
 )
 IP_CODER_inst
 (
 .RST                       (RST),
 .CLK                       (CLK),

 .IP_HEADER                 (IP_HEADER),
 .ICMP_HEADER               (ICMP_HEADER),
 .UDP_HEADER                (UDP_HEADER),
 
 .IP_EN                     (IP_EN),
 .IP_TYPE                   (IP_TYPE),    
 .IP_OUT_DATA	      		(IP_DATA),
 .IP_DONE 		       		(IP_DONE),

 // ICMP данные
 .ICMP_TX_DATA_REQ		    (ICMP_TX_DATA_REQ),
 .ICMP_TX_DATA				(ICMP_TX_DATA),		// [7:0]
 .ICMP_TX_DATA_VLD		    (ICMP_TX_DATA_VLD),
 // UDP данные
 .DATA_FROM_USER			(DATA_FROM_USER),	
 .DATA_FROM_USER_VLD	    (DATA_FROM_USER_VLD),
 .UDP_DATA_REQUEST		    (UDP_DATA_REQUEST),	// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные
 .UDP_PACKET_NUMBER		    (UDP_PACKET_NUMBER),			// Порядковый номер передаваемой посылки для IP
 .UDP_DATA_LENGTH			(UDP_DATA_LENGTH),		// Количество передавамых байт
 .UDP_DATA_CHECKSUM		    (UDP_DATA_CHECKSUM)		// Контрольная сумма данных
 );    
         
endmodule
