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
������ ��������� ������ �� ����� 1500 ����.
������ �������� ������ �� 64 ���� ������ �� 1458 ����. ����� ���������� � ������� ETH_LENGTH_CODE.

������ �������� � �������������� ������. ��� ������, ��� �� ������ ������������� �� ����� ���� ���������� ������, ���� ���������, � �� ������ ��� ������������ ��� � ��������������� ������.
����� ��������������� ������ ���������� ���, ��� � ����� ������ ������ �������� �����, ����������� � ���� , ��������� �� ����� ��� ���� �����. � ����� ���� ���� ���� ������������� ��������, ����� ���� ����� ������������ �������� ������������ ��� �����.
��������������, ��������� ������������� ��������� �������� ��������, ���������� ������������ �� ����, � ��� �� ������������� �������� ������ � ��������� �������� ������� �� ������� ���������� �������� ������ � ����� ��������.
�� � ����� ��������� �� ����������� ������� ������ ��� ��������, ��������� �� ���������� UDP �������� �������� ������, �������, � ������� �� TCP, �� ������� ��������� ������� � ���, ��� ����� ������� ��������� �������. 
���� ���� �� ��������� �������� ����� � ����, �� �� ����, ��� �� �������� ������� ��� ��������� �������. 
*/
/*
EMAC ��� ���� Ethernet, 
Client ��� ������ �������������� ������ �� ���� � ������������,
User ��� ������� ������������
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
input [15:0]	USER_TX_DATA,			// ��������� ���������� ����� ���������� ���� ���� ������
input 			USER_TX_VLD,
input 			USER_DATA_PRECENCE,	    // ���� ����, ��� ����������, �� �������� ������� ������,�� �������� �������� ������. ����� ��� ������ �������������� �������� ������ ������ � ���������� �������� ������
output 			USER_DATA_PAUSE	
);
 wire           ETH_INT_CLK;            // Ethernet Internal CLK. ���������� ������������ �������� ������� ��� ������ ����������. 
 wire           GMII_RXCLK_bufr;
 wire           GMII_TXCLK_bufr;

 wire [7:0] 	EMACCLIENTRXD;			//  [7:0] ����������� ������ �� MAC ����
 wire 			EMACCLIENTRXDVLD;		//  ���������� ����������� ������ 
 wire [6:0]     EMACCLIENTRXSTATS;      // [6:0] ���������� �� ��������� �������� �����. 28 ������ ������ ���������� ��������������� �� 7 ��� �� ����  
 wire           EMACCLIENTRXSTATSVLD;    // ���������� �������������� ������ ���������
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
 //---------------------------------------------------- ������ �� ���������� ������� --------------------------------------------//
 //---------------------------------------------------------------------------------------------------------------------------------------//
////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// RX_wires /////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
// ���������� �� ��������� � ���������
wire [7:0] 		  RX_DATA;		
wire 		      RX_VLD;	
// ���������� � �������� ������
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
// ���������� �� ������ � �����������
wire [7:0] 		  TX_DATA;	
wire              TX_STOP;  // ����� �� �������� �������� , ��������� ����� �������� ������� ������ �� ������������	
wire 		      TX_VLD;	
// ��������� ������� ������������� ������
wire [3:0]        TX_MESS_TYPE;
wire              TX_MESS_TYPE_VLD;	
wire              TX_MESS_REQ_DONE;			

wire [14*8-1:0]   TX_MAC_HEADER;
wire [28*8-1:0]   TX_ARP_HEADER;							
wire [20*8-1:0]   TX_IP_HEADER;					
wire [8*8+4-1:0]  TX_ICMP_HEADER;
wire [8*8-1:0]    TX_UDP_HEADER;

// ����� ������ ������� ICMP ����� ��������� � �������
wire 			ICMP_TX_DATA_REQ;
wire 			ICMP_TX_DATA_VLD;
wire [7:0]  	ICMP_TX_DATA;

// ����� ������� ����� ������� � ������� ���������������� ������
wire 			OUT_DATA_RDY;			// �������� �����������, ��� � ���� ���������� ������ � �� ���������� ���������
wire [7:0] 		OUT_DATA;
wire 			OUT_DATA_VLD;
wire 			OUT_DATA_REQUEST;		// ���������� ������� � ���������, ����� ���������� � ������������ ����� �������� ������
wire [15:0]	    OUT_DATA_PACKET_NUMBER;	// ���������� ����� ������������ �������
wire [15:0]	    OUT_DATA_LENGTH;		// ���������� ����������� ����
wire [15:0]	    OUT_DATA_CHECKSUM;		// ����������� ����� ������

 
 (*LOC = "IDELAYCTRL_X2Y4" *)
IDELAYCTRL IDELAYCTRL_inst 
(.RDY(),    .REFCLK	(IDELCTRL_CLK_REF),     .RST		(RST)  ); 

//BUFG BUFG_inst (.O(GTX_CLK),   .I(CLK_125));
BUFR #     (   .BUFR_DIVIDE("BYPASS"),    .SIM_DEVICE("VIRTEX6"))
BUFR_CLK125 (   .O(ETH_INT_CLK),   .CE(1'b1),   .CLR(1'b0),   .I(CLK_125));

//BUFG BUFG_GMII_RX_CLK (.O(GMII_RXCLK_bufr),   .I(GMII_RXCLK));

BUFR #        (   .BUFR_DIVIDE("BYPASS"),    .SIM_DEVICE("VIRTEX6"))
BUFR_PHYRXCLK (   .O(GMII_RXCLK_bufr),   .CE(1'b1),   .CLR(1'b0),   .I(GMII_RXCLK));
 
// ���������� MAC-���� Ethernet 
//(* black_box *)  
EMAC_CORE EMAC_CORE_inst
 (
 // Asynchronous reset input
 .RESET            				(RST),							// I // ����������� ������ ����� ��������� ����
 // TX clock output
 .TX_CLK_OUT        			(GMIIMIICLKOUT),	            // O // ��������� �������� � ������������ �� ������ ����������� ug368 p141
 // TX clock input from BUFG
 .TX_CLK              			(ETH_INT_CLK),						// I // ������� ���� � �������� ������� DDR, ����� � PHY. ������� � ���� GMII_TX_CLK. �� ���  ���������� ������ ������ �� ������������ (125 ���)
  // Receive-side PHY clock on regional buffer, to EMAC
 .PHY_RX_CLK            		(GMII_RXCLK_bufr),    			// I//  �������, �� ������� ������������ ����������� ������ ������������� (125 ���)
 // Clock signal
 .GTX_CLK       				(ETH_INT_CLK),						// I // ������� �������� �������, ��������������� �� ������������ � ����� GTX_CLK PHY ���������� . ������� ������� � ������������ IEEE Std 802.3-2005
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
 .EMACCLIENTRXD        			(EMACCLIENTRXD),				// O // [7:0] ����������� ������ �� MAC ����
 .EMACCLIENTRXDVLD     			(EMACCLIENTRXDVLD),				// O // ���������� ����������� ������ 
 .EMACCLIENTRXGOODFRAME    		(),								// O // ������ � ���, ��� ���� ������ �������. �������������� � ������ ��������� ���������� �����. 
 .EMACCLIENTRXBADFRAME 			(),								// O // ������ � ���, ��� ���� ������ � ��������. �������������� � ������ ��������� ���������� �����. 
 .EMACCLIENTRXFRAMEDROP    		(),								// O // ������ ��������� ������� � ���, ��� ������ ������� ������ �� ������������ �� ������ ������ � ������� �������. ������ ���������, ���� � ���� �� ����������� ������ �������
 .EMACCLIENTRXSTATS   			(EMACCLIENTRXSTATS),		    // O // [6:0] ���������� �� ��������� �������� �����. 28 ������ ������ ���������� ��������������� �� 7 ��� �� ����  
 .EMACCLIENTRXSTATSVLD 			(EMACCLIENTRXSTATSVLD),		    // O // ���������� �������������� ������ ���������
 .EMACCLIENTRXSTATSBYTEVLD 		(EMACCLIENTRXSTATSBYTEVLD),		// O // ������ ������������� ������ ������� ����� �����, ������� ����� ���������� FCS. ������� � ������ ������ ������ 
 // Client TX
 .CLIENTEMACTXD            		(CLIENTEMACTXD),				// I // [7:0] ������ ��� ��������
 .CLIENTEMACTXDVLD         		(CLIENTEMACTXDVLD),				// I // ���������� ������ �� �����
 .EMACCLIENTTXACK          		(EMACCLIENTTXACK),				// O // ������ ������������. ���������, ��� ���� ������� ������ ���� ������
 .CLIENTEMACTXFIRSTBYTE    		(1'b0),		                    // I // ������ ������ ���� ������ LOW
 .CLIENTEMACTXUNDERRUN     		(1'b0),			                // I // ������ �������� ����, ��� ������� ���� ��������
 .EMACCLIENTTXCOLLISION    		(EMACCLIENTTXCOLLISION),		// O // ������ � ���, ��� �� ����� ���������� ��������. ��� �������� ������ ������������. �� ����������� � ��������������� ������
 .EMACCLIENTTXRETRANSMIT  		(EMACCLIENTTXRETRANSMIT),		// O // ������������ ��������� � �������� ��������. ������ ������ ������ ������ �������� �������� �����. �� ����������� � ��������������� ������
 .CLIENTEMACTXIFGDELAY     		(8'd200),			            // I // [7:0] Gap - �����, ������, �����. ��������������� ����������� �����. ����������� � ��������������� ������
 .EMACCLIENTTXSTATS        		(EMACCLIENTTXSTATS),			// O // ���������� �� ��������� ���������� ������. 32-� ������ ������ ���������� ��������������� �� ���� �� ���� 
 .EMACCLIENTTXSTATSVLD     		(EMACCLIENTTXSTATSVLD),			// O // ���������� �������������� ������ �����������
 .EMACCLIENTTXSTATSBYTEVLD 		(EMACCLIENTTXSTATSBYTEVLD),		// O // ������ ������������� �������� ������� ����� �����, ������� ����� ���������� FCS. ������� � ������ ������ �������� 
 // MAC control interface
 .CLIENTEMACPAUSEREQ       		(1'b0),//(CLIENTEMACPAUSEREQ),	// I // ������������ �������� ��� �������� ����� �����
 .CLIENTEMACPAUSEVAL       		(16'b0)//(CLIENTEMACPAUSEVAL)	// I // ??? � ������� ������������ ����� ��� ����������� ��� ������� � ������������ IEEE Std 802.3-2005
 );
 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////// RX CHANNEL ///////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
     
     CLIENT_MAC_RX CLIENT_RX_BUFFER
    (
    .RST						(RST),
    // EMAC CORE SIDE
    .EMAC_RXDATA			    (EMACCLIENTRXD),    			//  [7:0] ����������� ������ �� MAC ����
    .EMAC_RXDATA_VLD		    (EMACCLIENTRXDVLD),        		//  ���������� ����������� ������ 
    .EMAC_RXCLK			        (GMII_RXCLK_bufr),   			//  �������� ������� c ������ ���������� Alaska ��� ������ ������  
    .EMAC_RXSTATS               (EMACCLIENTRXSTATS),            // [6:0] ���������� �� ��������� �������� �����. 28 ������ ������ ���������� ��������������� �� 7 ��� �� ����  
    .EMAC_RXSTATSVLD            (EMACCLIENTRXSTATSVLD),         // ���������� �������������� ������ ���������
    .EMAC_RXSTATSBYTEVLD        (EMACCLIENTRXSTATSBYTEVLD),
    // DECODER SIDE
    .CLIENT_CLK  				(ETH_INT_CLK),
    .CLIENT_DATA				(RX_DATA),						// [7:0]
    .CLIENT_DATA_VLD			(RX_VLD),
    .RX_STOP                    (),         // ������ ��� ������������ ������ ������
    .RX_RST                     (MAC_DONE) 
    ); 
////////////////////////////////////////////////////////////////////////////
///// ������� ����������� ������� �� MAC ���� ///
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
      .CLK                (ETH_INT_CLK),            // ���������� �� ����������

      .IN_PACKET_DATA     (RX_DATA),            // �� ���������
      .IN_PACKET_VLD      (RX_VLD),
		
      .MESS_TYPE          (RX_MESS_TYPE),  
      .MAC_DONE           (RX_MESS_TYPE_VLD),      // O ������ ���������� ������ ������
      // ������ ����������
      .MAC_HEADER         (RX_MAC_HEADER),		   // O [14*8-1:0]
      .ARP_HEADER         (RX_ARP_HEADER),         // O [28*8-1:0]
      .IP_HEADER          (RX_IP_HEADER),          // O [20*8-1:0]
      .ICMP_HEADER        (RX_ICMP_HEADER),        // O [8*8+4-1:0]
      .UDP_HEADER         (RX_UDP_HEADER),         // O [8*8-1:0]

      .ICMP_TX_DATA_REQ   (ICMP_TX_DATA_REQ),      //
      .ICMP_TX_DATA       (ICMP_TX_DATA),          // ��������� ������ ��������� ICMP ������� 
      .ICMP_TX_DATA_VLD   (ICMP_TX_DATA_VLD),      // 

      // �������� ������ �� ������ UDP
      .USER_CLK           (USER_RX_CLK),           // ��������� ������ ������� ������ �� UDP ������
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
    
    // �������� ������� �������� �� �������� ������
    .IN_MESS_TYPE_VLD       (RX_MESS_TYPE_VLD), //
    .IN_MESS_TYPE           (RX_MESS_TYPE),     // ��� �������� ������������������� �������. 
    .USER_DATA_TRANSFER_REQ (OUT_DATA_RDY),// ������ �� ������������ �� �������� ������
    
    .IN_MAC_HEADER          (RX_MAC_HEADER),    // [14*8-1:0]  
    .IN_ARP_HEADER          (RX_ARP_HEADER),    // [28*8-1:0]
    .IN_IP_HEADER           (RX_IP_HEADER),     // [20*8-1:0]
    .IN_ICMP_HEADER         (RX_ICMP_HEADER),   // [8*8+4-1:0]
    .IN_UDP_HEADER          (RX_UDP_HEADER),    // [8*8-1:0]
    //.TCP_HEADER           (), //
    
    // ��������� ������������ ����� � ������ ������� � ���������� �������
    .OUT_BUF_STATE          (TX_STOP),          // I 1 - �������� ����� �������� ������ ����������(������ ����������), 0 - �������� ����� �������� ������ ��������(����� ����������)
    
    .OUT_REQ_TYPE           (TX_MESS_TYPE),     // ��� ��������� �������
    .OUT_REQ_TYPE_VLD       (TX_MESS_TYPE_VLD), //               
    .REQ_DONE               (TX_MESS_REQ_DONE), // ��������� ������� ���������
    
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
     	.IN_DATA					(USER_TX_DATA),				    //I// ����� ������ ������ �� ���
     	.IN_DATA_VLD				(USER_TX_VLD),					//I
     	.IN_DATA_PRECENCE		    (USER_DATA_PRECENCE),	        //I// ���� ����, ��� ����������, �� �������� ������� ������,�� �������� �������� ������. ����� ��� ������ �������������� �������� ������ ������ � ���������� �������� ������
     	.IN_DATA_FLOW_PAUSE  	    (USER_DATA_PAUSE),				//O
     	
     	.OUT_DATA_CLK				(ETH_INT_CLK),					//I
     	.OUT_DATA_RDY				(OUT_DATA_RDY),				    //O// �������� DATA_CHANGING_CONTROLLER, ��� � DATA_DOZATOR ���������� ������ � �� ���������� ���������
     	.OUT_DATA					(OUT_DATA),				        //O
     	.OUT_DATA_VLD				(OUT_DATA_VLD),				    //O
     	.OUT_DATA_REQUEST	        (OUT_DATA_REQUEST),		        //I// ���������� ������� � ���������, ����� ���������� � ������������ ����� �������� ������

     	.PACKET_NUMBER    	        (OUT_DATA_PACKET_NUMBER),	    //O// ���������� ����� ������������ �������
     	.OUT_DATA_LENGTH		    (OUT_DATA_LENGTH),		        //O// ���������� ����������� ����
    	.OUT_DATA_CHECKSUM	        (OUT_DATA_CHECKSUM)	            //O// ����������� ����� ������
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
	// ICMP ������ �� ��������
	   .ICMP_TX_DATA_REQ		(ICMP_TX_DATA_REQ),
	   .ICMP_TX_DATA			(ICMP_TX_DATA),				     //[7:0]
	   .ICMP_TX_DATA_VLD		(ICMP_TX_DATA_VLD),
	// UDP ������ ��� ��������
	   .DATA_FROM_USER			(OUT_DATA),			// [7:0]
       .DATA_FROM_USER_VLD		(OUT_DATA_VLD),
	   .UDP_DATA_REQUEST		(OUT_DATA_REQUEST),		// ���������� ������� � ���������, ����� ���������� � ������������ ����� �������� ������
	   .UDP_PACKET_NUMBER		(OUT_DATA_PACKET_NUMBER),		// ���������� ����� ������������ ������� ��� IP
	   .UDP_DATA_LENGTH			(OUT_DATA_LENGTH),		// ���������� ����������� ����
	   .UDP_DATA_CHECKSUM		(OUT_DATA_CHECKSUM),	// ����������� ����� ������
	
	   .OUT_PACKET_DATA			(TX_DATA),			     // [7:0]		// ������ � ��������� ������ Ethernet
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
        .EMAC_CLK           (ETH_INT_CLK),	   //  �������� ������� �� ���� ���������� Alaska ��� �������� ������  
        .EMAC_TXD           (CLIENTEMACTXD),	   //  [7:0] ������ ��� ��������
        .EMAC_TXDVLD        (CLIENTEMACTXDVLD),    //  ���������� ������ �� �����
        .EMAC_TXACK         (EMACCLIENTTXACK),    //  ������ ������������. ���������, ��� ���� ������� ������ ���� ������
        .EMAC_TXSTATS       (EMACCLIENTTXSTATS),    //  ���������� �� ��������� ���������� ������. 32-� ������ ������ ���������� ��������������� �� ���� �� ���� 
        .EMAC_TXSTATSVLD    (EMACCLIENTTXSTATSVLD),    //  ���������� �������������� ������ �����������
        .EMAC_TXSTATSBYTEVLD(EMACCLIENTTXSTATSBYTEVLD),	   //  ������ ������������� �������� ������� ����� �����, ������� ����� ���������� FCS. ������� � ������ ������ �������� 
        .EMAC_TXCOLLISION   (EMACCLIENTTXCOLLISION),    //  ������ � ���, ��� �� ����� ���������� ��������. ��� �������� ������ ������������. �� ����������� � ��������������� ������
        .EMAC_TXRETRANSMIT  (EMACCLIENTTXRETRANSMIT)     //  �� ����������. ������������ ��������� � �������� ��������. ������ ������ ������ ������ �������� �������� �����. �� ����������� � ��������������� ������
    );
    
endmodule
