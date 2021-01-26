`timescale 1ns / 1ps
/*
Декодирует принимаемый пакет на части:
1) MAC данные
2) IP данные
3) TCP данные
4) Полезная нагрузка
*/

/*
В декодер UDP вставлен костыль, что принимает только 9 байт и все, и перестает работать )))). Если так не сделать, то сигнал валидности пустых данных приходит несколько раз. 
Нужно чтобы программист передавать в первых двух байтах количество данных, которое он передает в ПЛИС по UDP. 
*/

/*
PACKET_DECODER		
#(
.HTGv6_IP_ADDR 			(),
.HTGv6_MAC_ADDR 		()
)
PACKET_DECODER_inst
(
.RST                (),
.CLK                (),

.IN_PACKET_DATA     (),       // От приемника
.IN_PACKET_VLD      (),
// MAC данные
.MAC_HEADER         (),			// Для MAC Coder		
.MAC_DONE           (),
// ARP данные
.ARP_HEADER         (),
// IP данные
.IP_HEADER          (),
//ICMP данные
.ICMP_HEADER        (),
.ICMP_TX_DATA_REQ   (),
.ICMP_TX_DATA       (),
.ICMP_TX_DATA_VLD   (),
//UDP данные
.UDP_HEADER         (),
// Полезные данные из пакета UDP
.USER_CLK           (),
.USER_DATA          (),							
.USER_DATA_VLD      ()					
 );
*/
module PACKET_DECODER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01,
parameter HTGv6_UDP_PORT    = 16'h00_01
)
(
input 			   RST,
input 			   CLK,

input  [7:0] 	   IN_PACKET_DATA,       // От приемника
input 			   IN_PACKET_VLD,
// MAC данные
output [14*8-1:0]  MAC_HEADER, // Для MAC Coder
output [3:0]       MESS_TYPE,  // Тип принятого сообщения. MESS_TYPE[1:0] - тип запроса на сетевом уровне (ARP,RARP,IP);MESS_TYPE[3:2] - тип запроса на транспортном уровне(ICMP,UDP,TCP)		
output             MAC_DONE,
// ARP данные
output [28*8-1:0]  ARP_HEADER,
// IP данные
output [20*8-1:0]  IP_HEADER,
//ICMP данные
output [8*8+4-1:0] ICMP_HEADER,
input 			   ICMP_TX_DATA_REQ,
output [7:0]	   ICMP_TX_DATA,
output 			   ICMP_TX_DATA_VLD,
//UDP данные
output [8*8-1:0]   UDP_HEADER,
// Полезные данные из пакета UDP
input              USER_CLK,
output [71:0]      USER_DATA,							
output             USER_DATA_VLD					
 );
 
wire        ARP_DECODER_EN;
wire        ARP_DONE;
wire        IP_DECODER_EN;
wire        IP_DONE;

wire [1:0]  ARP_TYPE;
wire [1:0]  IP_TYPE;

wire        UDP_DATA_VLD;
wire [71:0] UDP_DATA; 
wire        FIFO_OUT_VALID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////   
/////////////////////////////////////////// MAC ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
 MAC_DECODER	 
 #(
 .HTGv6_MAC_ADDR            (HTGv6_MAC_ADDR)
 )
 MAC_DECODER_inst	
 (
 .RST					   	(RST),
 .CLK						(CLK),
 .IN_DATA					(IN_PACKET_DATA),
 .IN_DATA_VLD  				(IN_PACKET_VLD),
 
 .ARP_TYPE                  (ARP_TYPE),
 .IP_TYPE                   (IP_TYPE),
 // MAC данные
 .MAC_HEADER                (MAC_HEADER), // [14*8-1:0]	
 .MESS_TYPE                 (MESS_TYPE),
 .MAC_DONE                  (MAC_DONE),   // Сигнал полного завершения обработки принятого пакета
 // MAC Запросы
 .ARP_DECODER_EN			(ARP_DECODER_EN),
 .ARP_DONE					(ARP_DONE),
 .IP_DECODER_EN			   	(IP_DECODER_EN),
 .IP_DONE				   	(IP_DONE)
 );
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////   
 /////////////////////////////////////////// ARP /////////////////////////////////////////////////////////
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////
ARP_DECODER	
#(
.HTGv6_IP_ADDR 				(HTGv6_IP_ADDR)
)
ARP_DECODER_inst			// Производит прием ARP запросов
(
.RST						(RST),
.CLK						(CLK),

.IN_DATA					(IN_PACKET_DATA),		// [7:0]
.IN_DATA_VLD    			(IN_PACKET_VLD),

.ARP_EN						(ARP_DECODER_EN),
.ARP_HEADER                 (ARP_HEADER),
.ARP_TYPE                   (ARP_TYPE),
.ARP_DONE    				(ARP_DONE)
);
////////////////////////////////////////////////////////////////////////////////////////////////////////////   
/////////////////////////////////////////// IPv4 ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
IP_DECODER    
#(
.HTGv6_IP_ADDR 	        	(HTGv6_IP_ADDR),
.HTGv6_UDP_PORT         	(HTGv6_UDP_PORT)
)
IP_DECODER_inst
(
.RST                   		(RST),
.CLK                  		(CLK),

.IN_DATA               		(IN_PACKET_DATA),           // [63:0]
.IN_DATA_VLD          		(IN_PACKET_VLD),
// IP данные
.IP_EN                      (IP_DECODER_EN),
.IP_HEADER                  (IP_HEADER),  //[20*8-1:0]
.IP_TYPE                    (IP_TYPE),
.IP_DONE                    (IP_DONE),

// ICMP данные
.ICMP_HEADER                (ICMP_HEADER),  // [8*8+4-1:0]
.ICMP_TX_DATA_REQ			(ICMP_TX_DATA_REQ),
.ICMP_TX_DATA				(ICMP_TX_DATA),		// [7:0]
.ICMP_TX_DATA_VLD			(ICMP_TX_DATA_VLD),
// UDP данные
.UDP_HEADER                 (UDP_HEADER),  // [8*8-1:0]
.UDP_DATA_VLD				(UDP_DATA_VLD),
.UDP_DATA					(UDP_DATA) 				// [71:0]
);


UDP_DATA_MODULE 
#(
.DATA_WIDTH (72)
)
UDP_DATA_MODULE
(
.RST            (RST),

.DATA_I_CLK     (CLK),
.DATA_I         (UDP_DATA),
.DATA_I_VLD     (UDP_DATA_VLD),

.DATA_O_CLK     (USER_CLK),
.DATA_O_VLD     (USER_DATA_VLD),
.DATA_O         (USER_DATA)
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
     	    
     	    .TRIG0			({UDP_DATA[60:0],FIFO_OUT_VALID,USER_DATA_VLD,UDP_DATA_VLD}), // IN BUS [63:0]
     	    .TRIG1			({USER_DATA[63:0]}) // IN BUS [63:0]
     	);
*/
endmodule
