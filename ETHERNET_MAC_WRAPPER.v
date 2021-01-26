`timescale 1ns / 1ps

/*
ETHERNET_MAC_WRAPPER
#(
.HTGv6_IP_ADDR		(),
.HTGv6_MAC_ADDR	    (),
.HTGv6_UDP_PORT     ()
)
 ETHERNET_MAC_WRAPPER_inst
(
.MAC_RST			(),
.PHY_EMAC_GTXCLK    (),
// TX Side
.GMII_TXCLK		    (),
.GMII_TXEN			(),
.GMII_TXER			(),
.GMII_TXD			(),
// RX Side
.GMII_RXCLK			(),
.GMII_RXDV			(),
.GMII_RXER			(),
.GMII_RXD			(),
.GMII_COL			(),
.GMII_CRS			(),

.USER_RX_CLK		(),
.USER_RX_DATA		(),
.USER_RX_VLD		(),

.USER_TX_CLK		(),
.USER_TX_DATA       (),
.USER_TX_VLD	    (),
.IN_DATA_PRECENCE   (),
.IN_DATA_PAUSE      ()
);
*/

/*
Модуль принимает пакеты не более 1500 байт.
Модуль передает пакеты от 64 байт данных до 1458 байт. Выбор происходит с помощью ETH_LENGTH_CODE.

Модуль работает в полудуплексном режиме. Это значит, что по каналу единовременно мы можем либо передавать данные, либо принимать, а не делать это одновременно как в полнодуплексном режиме.
Выбор полудуплексного режима обусловлен тем, что в таком режиме должны работать точки, находящиеся в сети , состоящей из более чем двух точек. В такой сети есть риск возникновения коллизий, когда один канал одновременно пытаются использовать две точки.
Соответственно, возникает необходимость обработки сигналов коллизий, приходящих пользователю от ядра, а так же необходимость хранения данных в некотором выходном буффере до полного завершения передачи данных в канал передачи.
Но и такая обработка не гарантирует минимум ошибок при передаче, поскольку мы используем UDP протокол передачи данных, который, в отличие от TCP, не требует ответного сигнала о том, что обмен данными произошел успешно. 
Даже если мы правильно выкинули пакет в сеть, то не факт, что на применой стороне его правильно приняли. 
*/
/*
EMAC это ядро Ethernet, 
Client это логика преобразования данных от ядра к пользователю,
User это сигналы пользователя
*/

module ETHERNET_MAC_WRAPPER
#(
parameter HTGv6_IP_ADDR 	= 32'hC0_A8_00_01,
parameter HTGv6_MAC_ADDR 	= 48'h00_0A_35_00_00_01,
parameter HTGv6_UDP_PORT    = 16'h00_01
)
(
input 			RST,
input [2:0]     ETH_LENGTH_CODE,

input 			CLK_125,
input 			IDELCTRL_CLK_REF,
// TX Side
output          GMIIMIICLKOUT,
output			GMII_TXCLK,
output 			GMII_TXEN,
output 			GMII_TXER,
output [7:0] 	GMII_TXD,
// RX Side
input 			GMII_RXCLK,
input			GMII_RXDV,
input 			GMII_RXER,
input [7:0] 	GMII_RXD,
input 			GMII_COL,
input 			GMII_CRS,
// USER_SIGNALS
input 			USER_RX_CLK,
output [71:0]	USER_RX_DATA,
output  		USER_RX_VLD,

input 			USER_TX_CLK,
input [15:0]	USER_TX_DATA,			// Сторонние приложения будут направлять сюда свои данные
input 			USER_TX_VLD,
input 			USER_DATA_PRECENCE,	    // Флаг того, что устройство, от которого получаю данные,не окончило передачу данных. Тогда мой модуль инкрементирует значение номера пакета и продолжает передачу данных
output 			USER_DATA_PAUSE	
);
 wire           ETH_INT_CLK;            // Ethernet Internal CLK. Внутренняя региональная тактовая частота для работы интерфейса. 
 wire           GMII_RXCLK_bufr;
 wire           GMII_TXCLK_bufr;

 wire [7:0] 	EMACCLIENTRXD;			//  [7:0] Принимаемые данные от MAC ядра
 wire 			EMACCLIENTRXDVLD;		//  Валидность принимаемых данных 
 wire [6:0]     EMACCLIENTRXSTATS;      // [6:0] Статистика по последним принятым даным. 28 битный вектор передается последовательно по 7 бит за такт  
 wire           EMACCLIENTRXSTATSVLD;    // Валидность статистических данных приемника
 wire           EMACCLIENTRXSTATSBYTEVLD;

 wire [7:0] 	CLIENTEMACTXD;            				
 wire			CLIENTEMACTXDVLD;         			
 wire 			EMACCLIENTTXACK;     
 wire 			EMACCLIENTTXCOLLISION;   
 wire 			EMACCLIENTTXRETRANSMIT;  		
 wire 			EMACCLIENTTXSTATS;        							
 wire 			EMACCLIENTTXSTATSVLD;     					
 wire 			EMACCLIENTTXSTATSBYTEVLD; 
 //---------------------------------------------------------------------------------------------------------------------------------------//
 //---------------------------------------------------- Данные из заголовков пакетов --------------------------------------------//
 //---------------------------------------------------------------------------------------------------------------------------------------//
////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// RX_wires /////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
// Проводники от приемника к декодерам
wire [7:0] 		  RX_DATA;		
wire 		      RX_VLD;	
// Информация о принятом пакете
wire [3:0]        RX_MESS_TYPE;
wire              RX_MESS_TYPE_VLD;				

wire [14*8-1:0]   RX_MAC_HEADER;
wire [28*8-1:0]   RX_ARP_HEADER;							
wire [20*8-1:0]   RX_IP_HEADER;					
wire [8*8+4-1:0]  RX_ICMP_HEADER;
wire [8*8-1:0]    RX_UDP_HEADER;

////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// TX_wires /////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
// Проводники от кодера к передатчику
wire [7:0] 		  TX_DATA;	
wire              TX_STOP;  // Чтобы не возникло коллизии , закрывает прием выходным буфером данных от пользователя	
wire 		      TX_VLD;	
// Параметры запроса передаваемого пакета
wire [3:0]        TX_MESS_TYPE;
wire              TX_MESS_TYPE_VLD;	
wire              TX_MESS_REQ_DONE;			

wire [14*8-1:0]   TX_MAC_HEADER;
wire [28*8-1:0]   TX_ARP_HEADER;							
wire [20*8-1:0]   TX_IP_HEADER;					
wire [8*8+4-1:0]  TX_ICMP_HEADER;
wire [8*8-1:0]    TX_UDP_HEADER;

// Канал обмена данными ICMP между декодером и кодером
wire 			ICMP_TX_DATA_REQ;
wire 			ICMP_TX_DATA_VLD;
wire [7:0]  	ICMP_TX_DATA;

// Обмен данными между кодером и памятью пользовательских данных
wire 			OUT_DATA_RDY;			// Сообщаем передатчику, что в ФИФО содержатся данные и их необходимо отправить
wire [7:0] 		OUT_DATA;
wire 			OUT_DATA_VLD;
wire 			OUT_DATA_REQUEST;		// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные
wire [15:0]	    OUT_DATA_PACKET_NUMBER;	// Порядковый номер передаваемой посылки
wire [15:0]	    OUT_DATA_LENGTH;		// Количество передавамых байт
wire [15:0]	    OUT_DATA_CHECKSUM;		// Контрольная сумма данных

 
 (*LOC = "IDELAYCTRL_X2Y4" *)
IDELAYCTRL IDELAYCTRL_inst 
(.RDY(),    .REFCLK	(IDELCTRL_CLK_REF),     .RST		(RST)  ); 

//BUFG BUFG_inst (.O(GTX_CLK),   .I(CLK_125));
BUFR #     (   .BUFR_DIVIDE("BYPASS"),    .SIM_DEVICE("VIRTEX6"))
BUFR_CLK125 (   .O(ETH_INT_CLK),   .CE(1'b1),   .CLR(1'b0),   .I(CLK_125));

//BUFG BUFG_GMII_RX_CLK (.O(GMII_RXCLK_bufr),   .I(GMII_RXCLK));

BUFR #        (   .BUFR_DIVIDE("BYPASS"),    .SIM_DEVICE("VIRTEX6"))
BUFR_PHYRXCLK (   .O(GMII_RXCLK_bufr),   .CE(1'b1),   .CLR(1'b0),   .I(GMII_RXCLK));
 
// Аппаратное MAC-ядро Ethernet 
//(* black_box *)  
EMAC_CORE EMAC_CORE_inst
 (
 // Asynchronous reset input
 .RESET            				(RST),							// I // Асинхронный полный сброс регистров ядра
 // TX clock output
 .TX_CLK_OUT        			(GMIIMIICLKOUT),	            // O // Оставляем открытым в соответствии со схемой подключения ug368 p141
 // TX clock input from BUFG
 .TX_CLK              			(ETH_INT_CLK),						// I // Частота идет в выходной регистр DDR, затем в PHY. Выходит в виде GMII_TX_CLK. На ней  происходит запись данных от пользователя (125 МГц)
  // Receive-side PHY clock on regional buffer, to EMAC
 .PHY_RX_CLK            		(GMII_RXCLK_bufr),    			// I//  Частота, на которой производится считываение данных пользователем (125 МГц)
 // Clock signal
 .GTX_CLK       				(ETH_INT_CLK),						// I // Опорная тактовая частота, предоставляемая от пользователя к порту GTX_CLK PHY микросхемы . Допуски описаны в спецификации IEEE Std 802.3-2005
 //////////////// GMII interface /////////////////////
 // TX
 .GMII_TXD   					(GMII_TXD),						// O //
 .GMII_TX_EN 					(GMII_TXEN),					// O //
 .GMII_TX_ER 					(GMII_TXER),					// O //
 .GMII_TX_CLK					(GMII_TXCLK),    			    // O //
 //RX
 .GMII_RXD                		(GMII_RXD),						// I //
 .GMII_RX_DV              		(GMII_RXDV),					// I //
 .GMII_RX_ER              		(GMII_RXER),					// I //
 .GMII_RX_CLK             		(GMII_RXCLK),			        // I //
 //////////////// Client interface ////////////////////
 // Client RX
 .EMACCLIENTRXD        			(EMACCLIENTRXD),				// O // [7:0] Принимаемые данные от MAC ядра
 .EMACCLIENTRXDVLD     			(EMACCLIENTRXDVLD),				// O // Валидность принимаемых данных 
 .EMACCLIENTRXGOODFRAME    		(),								// O // Сигнал о том, что кадр принят успешно. Активизируется в момент получения последнего байта. 
 .EMACCLIENTRXBADFRAME 			(),								// O // Сигнал о том, что кадр принят с ошибками. Активизируется в момент получения последнего байта. 
 .EMACCLIENTRXFRAMEDROP    		(),								// O // Сигнал оповещает клиента о том, что адреса входных данных не соответсвуют ни одному адресу в фильтре адресов. Сигнал постоянен, если в ядре не применяется фильтр адресов
 .EMACCLIENTRXSTATS   			(EMACCLIENTRXSTATS),		    // O // [6:0] Статистика по последним принятым даным. 28 битный вектор передается последовательно по 7 бит за такт  
 .EMACCLIENTRXSTATSVLD 			(EMACCLIENTRXSTATSVLD),		    // O // Валидность статистических данных приемника
 .EMACCLIENTRXSTATSBYTEVLD 		(EMACCLIENTRXSTATSBYTEVLD),		// O // Сигнал подтверждения приема каждого байта кадра, включая адрес назначения FCS. Активен в каждый период приема 
 // Client TX
 .CLIENTEMACTXD            		(CLIENTEMACTXD),				// I // [7:0] Данные для передачи
 .CLIENTEMACTXDVLD         		(CLIENTEMACTXDVLD),				// I // Валидность данных на входе
 .EMACCLIENTTXACK          		(EMACCLIENTTXACK),				// O // Сигнал согласования. Оповещает, что ядро приняло первый байт данных
 .CLIENTEMACTXFIRSTBYTE    		(1'b0),		                    // I // Сигнал должен быть уровня LOW
 .CLIENTEMACTXUNDERRUN     		(1'b0),			                // I // Клиент сообщает ядру, что текущий кадр испорчен
 .EMACCLIENTTXCOLLISION    		(EMACCLIENTTXCOLLISION),		// O // Сигнал о том, что на линии происходит коллизия. Все передачи должны прекратиться. Не применяется в полнодуплексном режиме
 .EMACCLIENTTXRETRANSMIT  		(EMACCLIENTTXRETRANSMIT),		// O // Выставляется совместно с сигналом коллизии. Клиент обязан заново начать передачу текущего кадра. Не применяется в полнодуплексном режиме
 .CLIENTEMACTXIFGDELAY     		(8'd200),			            // I // [7:0] Gap - зазор, разрыв, брешь. Конфигурируемый межкадровый зазор. применяется в полнодуплексном режиме
 .EMACCLIENTTXSTATS        		(EMACCLIENTTXSTATS),			// O // Статистика по последним переданным данным. 32-х битный вектор передается последовательно по биту за такт 
 .EMACCLIENTTXSTATSVLD     		(EMACCLIENTTXSTATSVLD),			// O // Валидность статистических данных передатчика
 .EMACCLIENTTXSTATSBYTEVLD 		(EMACCLIENTTXSTATSBYTEVLD),		// O // Сигнал подтверждения передачи каждого байта кадра, включая адрес назначения FCS. Активен в каждый период передачи 
 // MAC control interface
 .CLIENTEMACPAUSEREQ       		(1'b0),//(CLIENTEMACPAUSEREQ),	// I // Активируется клиентом для передачи кадра паузы
 .CLIENTEMACPAUSEVAL       		(16'b0)//(CLIENTEMACPAUSEVAL)	// I // ??? В течение длительности паузы для передатчика как описано в спецификации IEEE Std 802.3-2005
 );
 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////// RX CHANNEL ///////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
     
     CLIENT_MAC_RX CLIENT_RX_BUFFER
    (
    .RST						(RST),
    // EMAC CORE SIDE
    .EMAC_RXDATA			    (EMACCLIENTRXD),    			//  [7:0] Принимаемые данные от MAC ядра
    .EMAC_RXDATA_VLD		    (EMACCLIENTRXDVLD),        		//  Валидность принимаемых данных 
    .EMAC_RXCLK			        (GMII_RXCLK_bufr),   			//  Тактовая частота c выхода микросхемы Alaska для приема данных  
    .EMAC_RXSTATS               (EMACCLIENTRXSTATS),            // [6:0] Статистика по последним принятым даным. 28 битный вектор передается последовательно по 7 бит за такт  
    .EMAC_RXSTATSVLD            (EMACCLIENTRXSTATSVLD),         // Валидность статистических данных приемника
    .EMAC_RXSTATSBYTEVLD        (EMACCLIENTRXSTATSBYTEVLD),
    // DECODER SIDE
    .CLIENT_CLK  				(ETH_INT_CLK),
    .CLIENT_DATA				(RX_DATA),						// [7:0]
    .CLIENT_DATA_VLD			(RX_VLD),
    .RX_STOP                    (),         // Сигнал для приостановки приема данных
    .RX_RST                     (MAC_DONE) 
    ); 
////////////////////////////////////////////////////////////////////////////
///// Декодер принимаемых пакетов от MAC ядра ///
////////////////////////////////////////////////////////////////////////////
          PACKET_DECODER		
     #(
          .HTGv6_IP_ADDR 			(HTGv6_IP_ADDR),
          .HTGv6_MAC_ADDR 			(HTGv6_MAC_ADDR),
          .HTGv6_UDP_PORT           (HTGv6_UDP_PORT)
       )
          PACKET_DECODER_inst
      (
      .RST                (RST),                // 
      .CLK                (ETH_INT_CLK),            // Внутренняя ТЧ интерфейса

      .IN_PACKET_DATA     (RX_DATA),            // От приемника
      .IN_PACKET_VLD      (RX_VLD),
		
      .MESS_TYPE          (RX_MESS_TYPE),  
      .MAC_DONE           (RX_MESS_TYPE_VLD),      // O Сигнал завершения приема пакета
      // Данные заголовков
      .MAC_HEADER         (RX_MAC_HEADER),		   // O [14*8-1:0]
      .ARP_HEADER         (RX_ARP_HEADER),         // O [28*8-1:0]
      .IP_HEADER          (RX_IP_HEADER),          // O [20*8-1:0]
      .ICMP_HEADER        (RX_ICMP_HEADER),        // O [8*8+4-1:0]
      .UDP_HEADER         (RX_UDP_HEADER),         // O [8*8-1:0]

      .ICMP_TX_DATA_REQ   (ICMP_TX_DATA_REQ),      //
      .ICMP_TX_DATA       (ICMP_TX_DATA),          // Интерфейс обмена принятыми ICMP данными 
      .ICMP_TX_DATA_VLD   (ICMP_TX_DATA_VLD),      // 

      // Полезные данные из пакета UDP
      .USER_CLK           (USER_RX_CLK),           // Интерфейс приема входных данных из UDP пакета
      .USER_DATA          (USER_RX_DATA),							
      .USER_DATA_VLD      (USER_RX_VLD)					
       );
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////// DATA_ARBITR ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////      
    DATA_CHANGING_CONTROLLER DATA_CHANGING_CONTROLLER_inst
    (
    .CLK                    (ETH_INT_CLK),
    .RST                    (RST),
    
    // Приемная внешних запросов на передачу данных
    .IN_MESS_TYPE_VLD       (RX_MESS_TYPE_VLD), //
    .IN_MESS_TYPE           (RX_MESS_TYPE),     // Тип входного непользовательского запроса. 
    .USER_DATA_TRANSFER_REQ (OUT_DATA_RDY),// запрос от пользователя на передачу данных
    
    .IN_MAC_HEADER          (RX_MAC_HEADER),    // [14*8-1:0]  
    .IN_ARP_HEADER          (RX_ARP_HEADER),    // [28*8-1:0]
    .IN_IP_HEADER           (RX_IP_HEADER),     // [20*8-1:0]
    .IN_ICMP_HEADER         (RX_ICMP_HEADER),   // [8*8+4-1:0]
    .IN_UDP_HEADER          (RX_UDP_HEADER),    // [8*8-1:0]
    //.TCP_HEADER           (), //
    
    // Интерфейс формирования задач и обмена данными с передающим модулем
    .OUT_BUF_STATE          (TX_STOP),          // I 1 - Выходной буфер передачи данных недоступен(нельзя записывать), 0 - Выходной буфер передачи данных доступен(можно записывать)
    
    .OUT_REQ_TYPE           (TX_MESS_TYPE),     // Тип выходного запроса
    .OUT_REQ_TYPE_VLD       (TX_MESS_TYPE_VLD), //               
    .REQ_DONE               (TX_MESS_REQ_DONE), // Обработка запроса завершена
    
    .OUT_MAC_HEADER         (TX_MAC_HEADER),    // [14*8-1:0]  
    .OUT_ARP_HEADER         (TX_ARP_HEADER),    // [28*8-1:0]  
    .OUT_IP_HEADER          (TX_IP_HEADER),     // [20*8-1:0]  
    .OUT_ICMP_HEADER        (TX_ICMP_HEADER),   // [8*8+4-1:0] 
    .OUT_UDP_HEADER         (TX_UDP_HEADER)     // [8*8-1:0]    
    //.TCP_HEADER           ()  //
    );      
           
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// TX CHANNEL //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  DATA_DOZATOR_v2  DATA_DOZATOR
     (
     	.RST						(RST),							//I
     	.LENGTH_CODE                (ETH_LENGTH_CODE),
     	
     	.IN_DATA_CLK				(USER_TX_CLK),					//I
     	.IN_DATA					(USER_TX_DATA),				    //I// Канал приема данных от АЦП
     	.IN_DATA_VLD				(USER_TX_VLD),					//I
     	.IN_DATA_PRECENCE		    (USER_DATA_PRECENCE),	        //I// Флаг того, что устройство, от которого получаю данные,не окончило передачу данных. Тогда мой модуль инкрементирует значение номера пакета и продолжает передачу данных
     	.IN_DATA_FLOW_PAUSE  	    (USER_DATA_PAUSE),				//O
     	
     	.OUT_DATA_CLK				(ETH_INT_CLK),					//I
     	.OUT_DATA_RDY				(OUT_DATA_RDY),				    //O// Сообщаем DATA_CHANGING_CONTROLLER, что в DATA_DOZATOR содержатся данные и их необходимо отправить
     	.OUT_DATA					(OUT_DATA),				        //O
     	.OUT_DATA_VLD				(OUT_DATA_VLD),				    //O
     	.OUT_DATA_REQUEST	        (OUT_DATA_REQUEST),		        //I// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные

     	.PACKET_NUMBER    	        (OUT_DATA_PACKET_NUMBER),	    //O// Порядковый номер передаваемой посылки
     	.OUT_DATA_LENGTH		    (OUT_DATA_LENGTH),		        //O// Количество передавамых байт
    	.OUT_DATA_CHECKSUM	        (OUT_DATA_CHECKSUM)	            //O// Контрольная сумма данных
      );
	
  PACKET_CODER		
	#(
	   .HTGv6_IP_ADDR			(HTGv6_IP_ADDR),
	   .HTGv6_MAC_ADDR 			(HTGv6_MAC_ADDR),
	   .HTGv6_UDP_PORT         	(HTGv6_UDP_PORT)
	)
	PACKET_CODER_inst
	(
	   .RST						(RST),
	   .CLK						(ETH_INT_CLK),
	
	   .MESS_TYPE               (TX_MESS_TYPE),  
       .MESS_TYPE_VLD           (TX_MESS_TYPE_VLD),      // I 
       .MESS_DONE               (TX_MESS_REQ_DONE),
	
	   .MAC_HEADER			    (TX_MAC_HEADER),	     // [14*8-1:0]		
	   .ARP_HEADER				(TX_ARP_HEADER),		 // [28*8-1:0]
	   .IP_HEADER				(TX_IP_HEADER),			 // [20*8-1:0]
       .ICMP_HEADER             (TX_ICMP_HEADER),        // [8*8+4-1:0]
       .UDP_HEADER              (TX_UDP_HEADER),         // [8*8-1:0]
	// ICMP данные от декодера
	   .ICMP_TX_DATA_REQ		(ICMP_TX_DATA_REQ),
	   .ICMP_TX_DATA			(ICMP_TX_DATA),				     //[7:0]
	   .ICMP_TX_DATA_VLD		(ICMP_TX_DATA_VLD),
	// UDP данные для передачи
	   .DATA_FROM_USER			(OUT_DATA),			// [7:0]
       .DATA_FROM_USER_VLD		(OUT_DATA_VLD),
	   .UDP_DATA_REQUEST		(OUT_DATA_REQUEST),		// Передатчик подошел к состоянию, когда необходимо в передаваемый пакет помещать данные
	   .UDP_PACKET_NUMBER		(OUT_DATA_PACKET_NUMBER),		// Порядковый номер передаваемой посылки для IP
	   .UDP_DATA_LENGTH			(OUT_DATA_LENGTH),		// Количество передавамых байт
	   .UDP_DATA_CHECKSUM		(OUT_DATA_CHECKSUM),	// Контрольная сумма данных
	
	   .OUT_PACKET_DATA			(TX_DATA),			     // [7:0]		// данные к выходному буферу Ethernet
       .OUT_PACKET_VLD			(TX_VLD)
	);
	
	
    CLIENT_MAC_TX CLIENT_MAC_TX
    (
        .RST                (RST),
    // CLIENT SIDE
        .CLIENT_CLK         (ETH_INT_CLK),
        .CLIENT_DATA        (TX_DATA),    // [7:0]
        .CLIENT_DATA_VLD    (TX_VLD),
        .CLIENT_TX_STOP     (TX_STOP),  
    // EMAC CORE SIDE
        .EMAC_CLK           (ETH_INT_CLK),	   //  Тактовая частота на вход микросхемы Alaska для передачи данных  
        .EMAC_TXD           (CLIENTEMACTXD),	   //  [7:0] Данные для передачи
        .EMAC_TXDVLD        (CLIENTEMACTXDVLD),    //  Валидность данных на входе
        .EMAC_TXACK         (EMACCLIENTTXACK),    //  Сигнал согласования. Оповещает, что ядро приняло первый байт данных
        .EMAC_TXSTATS       (EMACCLIENTTXSTATS),    //  Статистика по последним переданным данным. 32-х битный вектор передается последовательно по биту за такт 
        .EMAC_TXSTATSVLD    (EMACCLIENTTXSTATSVLD),    //  Валидность статистических данных передатчика
        .EMAC_TXSTATSBYTEVLD(EMACCLIENTTXSTATSBYTEVLD),	   //  Сигнал подтверждения передачи каждого байта кадра, включая адрес назначения FCS. Активен в каждый период передачи 
        .EMAC_TXCOLLISION   (EMACCLIENTTXCOLLISION),    //  Сигнал о том, что на линии происходит коллизия. Все передачи должны прекратиться. Не применяется в полнодуплексном режиме
        .EMAC_TXRETRANSMIT  (EMACCLIENTTXRETRANSMIT)     //  НЕ ИСПОЛЬЗУЕМ. Выставляется совместно с сигналом коллизии. Клиент обязан заново начать передачу текущего кадра. Не применяется в полнодуплексном режиме
    );
    
endmodule
