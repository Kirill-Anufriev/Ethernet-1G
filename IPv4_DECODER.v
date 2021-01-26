`timescale 1ns/1ps

/*
������� ����������� IPv4 ���������

� ������, ���� IP ����� ���������� � ����������� ��������� �� ��������� � IP ������� ���������� ���������� ��������� � �������� DONE � ��� ���������� ��� ������
*/

/*
IPv4_DECODER    IPv4_DECODER_inst
#(
.HTGv6_IP_ADDR 	        (),
.HTGv6_MAC_ADDR 		(),
.HTGv6_UDP_PORT      	()
)
(
.RST                   	(),
.CLK                	(),

.IN_DATA                (),  // [7:0]
.IN_DATA_VLD            (),
// IP ������
.IP_EN                  (),
.IP_HEADER              (),  //[20*8-1:0]
.IP_DONE                (),
// ICMP ������
.ICMP_HEADER            (),  // [8*8+4-1:0]
.ICMP_TX_DATA_REQ       (),
.ICMP_TX_DATA           (),  //[7:0]
.ICMP_TX_DATA_VLD       (),
// UDP ������
.UDP_HEADER             (),  // [8*8-1:0]
.UDP_DATA_VLD           (),
.UDP_DATA               ()   //[71:0] 
);
*/

`define ICMP_PROTOCOL   8'h01
`define UDP_PROTOCOL    8'h11
`define TCP_PROTOCOL    8'h06

`define UNSUPPORTED_TYPE_MES 2'b00
`define ICMP_TYPE_MES        2'b01
`define UDP_TYPE_MES         2'b10
`define TCP_TYPE_MES         2'b11

module IP_DECODER
#(
parameter HTGv6_IP_ADDR     = 32'hC0_A8_00_01,
parameter HTGv6_UDP_PORT    = 16'h00_01
)
(
input			       RST,
input     		       CLK,

input [7:0]	           IN_DATA,
input 			       IN_DATA_VLD,
// IP ������
input		           IP_EN,
output reg [20*8-1:0]  IP_HEADER,
output reg [1:0]       IP_TYPE, // 2'b00 - ICMP, 2'b01 - UDP, 2'b10 - TCP
output reg 		       IP_DONE,
// ICMP ������
output [8*8-1+4:0]     ICMP_HEADER,
input 			       ICMP_TX_DATA_REQ,
output [7:0] 	       ICMP_TX_DATA,
output			       ICMP_TX_DATA_VLD,
// UDP ������
output [8*8-1:0]       UDP_HEADER,
output 			       UDP_DATA_VLD,
output [71:0]	       UDP_DATA 			// [71:0]
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
localparam IP_ICMP_UDP_EN_ST 	= 5'b11111;
localparam IP_ICMP_ST  			= 5'b11101;
localparam IP_UDP_ST   			= 5'b10101;
localparam IP_DONE_ST   	 	= 5'b10001;


reg [3:0]  IP_VER;
reg [3:0]  IP_HDR_LENGTH;	         // ���������� � ���������� 32-� ������ ���� (������ 20 ���� = 5 DW, �������� 60 ���� = 15 DW)
reg [7:0]  IP_DIFF_SERV_FIELD;
reg [15:0] IP_TOTAL_LENGTH;			 // ����������� ����� ������ ������ � ������� (��������� + ������). �������� 65536, �� ����� Ethenet ���������� �� 1500 ���� � ������� ������
reg [15:0] IP_IDENTIFICATION;		 // ��� ������������� ������ ����������������� �������. � ���������� ������ ������ �� ������ ������ ���������� �������������
reg [2:0]  IP_FRAGMENT_FLAGS;		// [1] ������� �������������� ����� ��������������� ����� ��� ���,  [2] ��� �������� � ���, ��������� ��� ����� �� ������� ������� ������ ��� ���
reg [12:0] IP_FRAGMENT_OFFSET;		// ������������ ��� ������/�������� ���������� ������. ������ 8 ������
reg [7:0]  IP_TIME_TO_LIVE;			// ����� ����� ������. ���������� 64 ��� 128
reg [7:0]  IP_PROTOCOL;				 // ��������� ������ ��������� �������� ������ ���������� �������� ������. 1 - ICMP, 6 - TCP, 17 - UDP
reg [15:0] IP_CHECKSUM;				// ����������� ����� ��� �������� �� �������� ������ ������ ���������
reg [31:0] IP_SRC_IP_ADDR;			 // IP ����� ��������� ���������
reg [31:0] IP_DST_IP_ADDR;			// IP ����� ���������� ���������

(* fsm_encoding = "gray" *)
reg [4:0] IP_ST;

reg ICMP_EN;        // ������ � ������� ���������� ��������� ��������� ���������
reg UDP_EN;         //

reg [10:0] ICMP_WAIT_CNT;
reg [12:0] UDP_WAIT_CNT;

wire [1:0] ICMP_TYPE;
wire [1:0] UDP_TYPE;

wire ICMP_DONE; 
wire UDP_DONE;


always @(posedge CLK or posedge RST)
if (RST)							
begin
IP_ST 	     			<= IP_BYTE0_ST;
IP_DONE					<= 1'b0;	
	       
IP_VER					<= 4'b0;					
IP_HDR_LENGTH			<= 4'b0;
IP_DIFF_SERV_FIELD		<= 8'b0;
IP_TOTAL_LENGTH			<= 16'b0;
IP_IDENTIFICATION		<= 16'b0;
IP_FRAGMENT_FLAGS	    <= 3'b0;				
IP_FRAGMENT_OFFSET	    <= 13'b0;		
IP_TIME_TO_LIVE			<= 8'b0;
IP_PROTOCOL				<= 8'b0;
IP_CHECKSUM				<= 16'b0;
IP_SRC_IP_ADDR			<= 32'b0;
IP_DST_IP_ADDR			<= 32'b0;	

IP_HEADER               <= 160'b0;
IP_TYPE                 <= 2'b00;

UDP_EN                  <= 1'b0;		  
ICMP_EN                 <= 1'b0;
	
end
else 
(* parallel_case *)(* full_case *)
case (IP_ST)
// ����� ����� IP_VER � IP_HDR_LENGTH
IP_BYTE0_ST:		if (IP_EN)	
					   begin
						IP_ST 								<= IP_BYTE1_ST;
						IP_VER								<= IN_DATA[7:4];
						IP_HDR_LENGTH   					<= IN_DATA[3:0];
					   end
					else 					
					   begin
						IP_ST 								<= IP_BYTE0_ST;
						IP_VER								<= IP_VER;
						IP_HDR_LENGTH     					<= IP_HDR_LENGTH;
					   end
// ����� ����� IP_DIFF_SERV_FIELD													
IP_BYTE1_ST:		begin
						IP_ST								<= IP_BYTE2_ST;
						IP_DIFF_SERV_FIELD        			<= IN_DATA;
					end
// ����� ����� IP_TOTAL_LENGTH													
IP_BYTE2_ST:		begin                                                                          													
						IP_ST								<= IP_BYTE3_ST;                                                     														
						IP_TOTAL_LENGTH[15:8]	            <= IN_DATA;                                            														
					end  
IP_BYTE3_ST:		begin                                                                          
						IP_ST								<= IP_BYTE4_ST;                                                     
						IP_TOTAL_LENGTH[7:0]          		<= IN_DATA;                                            
					end     
// ����� ����� IP_IDENTIFICATION		
IP_BYTE4_ST:		begin                                                                          
						IP_ST 								<= IP_BYTE5_ST;                                                     
						IP_IDENTIFICATION[15:8]	            <= IN_DATA;                                            
					end      
IP_BYTE5_ST:		begin                                                                          
					    IP_ST 								<= IP_BYTE6_ST;                                                     
						IP_IDENTIFICATION[7:0]    		    <= IN_DATA;                                            
					end    
// ����� ����� IP_FRAGMENT_FLAGS � 	IP_FRAGMENT_OFFSET
IP_BYTE6_ST:		begin                                                                          
						IP_ST 								<= IP_BYTE7_ST;                                                     													                                                     														
						IP_FRAGMENT_FLAGS		            <= IN_DATA[7:5];  
					    IP_FRAGMENT_OFFSET[12:8]            <= IN_DATA[4:0];                                         														
					end    
IP_BYTE7_ST:		begin                                                                          			
						IP_ST 						      	<= IP_BYTE8_ST;                                                     			
						IP_FRAGMENT_OFFSET[7:0]             <= IN_DATA;                                           			
					end                                                                                   			
// ����� ����� IP_TIME_TO_LIVE	
IP_BYTE8_ST:		begin                                                                          			
						IP_ST 						      	<= IP_BYTE9_ST;                                                     			
						IP_TIME_TO_LIVE				        <= IN_DATA;                                            			
					end            
// ����� ����� IP_PROTOCOL													                                                                       			
IP_BYTE9_ST:		begin                                                                          			
						IP_ST 								<= IP_BYTE10_ST;                                                     			
						IP_PROTOCOL   						<= IN_DATA;                                            			
					end      
// ����� ����� IP_CHECKSUM													                                                                             			
IP_BYTE10_ST:		begin                                                                          			
						IP_ST 								<= IP_BYTE11_ST;                                                     			
						IP_CHECKSUM[15:8]				    <= IN_DATA;                                            			
					end                                                                                   			
IP_BYTE11_ST:		begin                                                                          			
						IP_ST 								<= IP_BYTE12_ST;                                                     			
						IP_CHECKSUM[7:0]				    <= IN_DATA;                                            			
					end   
// ����� ����� IP_SRC_IP_ADDR													
IP_BYTE12_ST:		begin                                                                          			
						IP_ST 								<= IP_BYTE13_ST;                                                     			
						IP_SRC_IP_ADDR[31:24]	    	    <= IN_DATA;                                            			
					end                                                                                   			
IP_BYTE13_ST:		begin
						IP_ST								<= IP_BYTE14_ST;
						IP_SRC_IP_ADDR[23:16]	    	    <= IN_DATA; 		
					end
IP_BYTE14_ST:		begin                                                                                    													
						IP_ST 								<= IP_BYTE15_ST;                                                               													
						IP_SRC_IP_ADDR[15:8]	 	        <= IN_DATA;                                                      													
					end                                                                                             													
IP_BYTE15_ST:		begin                                                                          																							
						IP_ST 								<= IP_BYTE16_ST;                                                     																							
					    IP_SRC_IP_ADDR[7:0]	       		    <= IN_DATA;                                            																							
					end                                                                                             													
// ����� ����� IP_DST_IP_ADDR
IP_BYTE16_ST:		begin                                                                                    													
						IP_ST 								<= IP_BYTE17_ST;                                                               													
						IP_DST_IP_ADDR[31:24]		        <= IN_DATA;                                                      													
					end                                                                                             													
IP_BYTE17_ST:		begin                                                                                    													
						IP_ST 							    <= IP_BYTE18_ST;                                                               													
						IP_DST_IP_ADDR[23:16]		        <= IN_DATA;                                                       													
					end   
IP_BYTE18_ST:		begin                                                                                    													
						IP_ST 						      	<= IP_BYTE19_ST;                                                               													
					    IP_DST_IP_ADDR[15:8]		        <= IN_DATA;                                                        													
					end                                                                                             													
IP_BYTE19_ST:		begin
						IP_DST_IP_ADDR[7:0]			        <= IN_DATA; 
						if (IP_PROTOCOL	 == `ICMP_PROTOCOL) 
						  begin
						       IP_ST 					    <= IP_ICMP_UDP_EN_ST;
						       ICMP_EN                      <= 1'b1;
						  end     	
						else if (IP_PROTOCOL	 == `UDP_PROTOCOL) 	 
						  begin
						       IP_ST 						<= IP_ICMP_UDP_EN_ST;
						       UDP_EN                       <= 1'b1;		
						  end 
    				//  else if (IP_PROTOCOL	 == `TCP_PROTOCOL) 	 
 					//	  begin
 					//	       IP_ST 						<= ?????;
 					//	       IP_TYPE                      <= `TCP_TYPE_MES; 
 					//	       UDP_EN                       <= 1'b1;		
 					//	  end   
						else   
						  begin
						      IP_ST 						<= IP_DONE_ST;
						      IP_TYPE                       <= `UNSUPPORTED_TYPE_MES;
						  end     				
					end
IP_ICMP_UDP_EN_ST:	if (IP_DST_IP_ADDR == HTGv6_IP_ADDR)
					   begin	
					       UDP_EN  <= 0;
					       ICMP_EN <= 0;
                           
						   if 	   (IP_PROTOCOL	 == `ICMP_PROTOCOL)	 
						      begin
						          IP_ST       <= IP_ICMP_ST;
						          IP_TYPE     <= `ICMP_TYPE_MES; 
						          IP_HEADER   <= {IP_DST_IP_ADDR,IP_SRC_IP_ADDR,IP_CHECKSUM,IP_PROTOCOL,IP_TIME_TO_LIVE,IP_FRAGMENT_OFFSET,IP_FRAGMENT_FLAGS,IP_IDENTIFICATION,IP_TOTAL_LENGTH,IP_DIFF_SERV_FIELD,IP_HDR_LENGTH,IP_VER};
						      end       
						   else if (IP_PROTOCOL	 == `UDP_PROTOCOL)	 
						      begin
						          IP_ST       <= IP_UDP_ST;
						          IP_TYPE     <= `UDP_TYPE_MES; 
						          IP_HEADER   <= {IP_DST_IP_ADDR,IP_SRC_IP_ADDR,IP_CHECKSUM,IP_PROTOCOL,IP_TIME_TO_LIVE,IP_FRAGMENT_OFFSET,IP_FRAGMENT_FLAGS,IP_IDENTIFICATION,IP_TOTAL_LENGTH,IP_DIFF_SERV_FIELD,IP_HDR_LENGTH,IP_VER};
						      end     
						   else 
						      begin
						        IP_DONE     <= 1'b1;
						        IP_TYPE     <= `UNSUPPORTED_TYPE_MES;
						        IP_HEADER   <= 160'b0;
						   		if (IN_DATA_VLD)      				     IP_ST <= IP_ICMP_UDP_EN_ST;
						   		else   		                             IP_ST <= IP_DONE_ST;				            
                              end  
					   end 
					else 
						begin
						    IP_DONE     <= 1'b1;
						    IP_TYPE     <= `UNSUPPORTED_TYPE_MES;
						    IP_HEADER   <= IP_HEADER;
                     		if (IN_DATA_VLD) 		                     IP_ST <= IP_ICMP_UDP_EN_ST;
                            else                                         IP_ST <= IP_DONE_ST;				            
                        end  
IP_ICMP_ST:			if (ICMP_WAIT_CNT <= 11'd300)
                        begin
                            if (ICMP_DONE)
                                begin
                                    IP_ST 		<= IP_DONE_ST;
                                    IP_DONE     <= 1'b1;
                                end     
                            else    IP_ST		<= IP_ICMP_ST;
                        end
                    else   
                        begin
                                    IP_ST		<= IP_DONE_ST;
                                    IP_DONE     <= 1'b1;
                                    IP_TYPE     <= `UNSUPPORTED_TYPE_MES;
                        end    
                    
IP_UDP_ST:		    if (UDP_WAIT_CNT <= 13'd2000)
                        begin
                            if (UDP_DONE)							
                                begin
                                    IP_ST 		<= IP_DONE_ST;
                                    IP_DONE 	<= 1'b1;
                                end    
                            else 	IP_ST		<= IP_UDP_ST;
                        end
                    else  
                        begin
                                    IP_ST 		<= IP_DONE_ST;
                                    IP_DONE 	<= 1'b1;
                                    IP_TYPE     <= `UNSUPPORTED_TYPE_MES;
                        end 
                    
IP_DONE_ST:			begin
							        IP_DONE		<= 1'b0;
							        IP_HEADER   <= IP_HEADER;
			     		            IP_ST 		<= IP_BYTE0_ST;
					end
default:			begin
							IP_ST 	     			<= IP_BYTE0_ST;
                            IP_DONE					<= 1'b0;
                            IP_HEADER               <= IP_HEADER;
                            IP_TYPE                 <= IP_TYPE;	
	
                            IP_VER					<= 4'b0;					
                            IP_HDR_LENGTH			<= 4'b0;
                            IP_DIFF_SERV_FIELD		<= 8'b0;
                            IP_TOTAL_LENGTH			<= 16'b0;
                            IP_IDENTIFICATION		<= 16'b0;
                            IP_FRAGMENT_FLAGS	    <= 3'b0;				
                            IP_FRAGMENT_OFFSET	    <= 13'b0;		
                            IP_TIME_TO_LIVE			<= 8'b0;
                            IP_PROTOCOL				<= 8'b0;
                            IP_CHECKSUM				<= 16'b0;
                            IP_SRC_IP_ADDR			<= 32'b0;
                            IP_DST_IP_ADDR			<= 32'b0;	

                            UDP_EN                  <= 1'b0;		  
                            ICMP_EN                 <= 1'b0;
					end
endcase

always @(posedge CLK or posedge RST)
if (RST)                        UDP_WAIT_CNT <= 13'd0;
else if (IP_ST == IP_UDP_ST)    UDP_WAIT_CNT <= UDP_WAIT_CNT + 1'b1;
else                            UDP_WAIT_CNT <= 13'd0;

always @(posedge CLK or posedge RST)
if (RST)                        ICMP_WAIT_CNT <= 11'd0;
else if (IP_ST == IP_ICMP_ST)   ICMP_WAIT_CNT <= ICMP_WAIT_CNT + 1'b1;
else                            ICMP_WAIT_CNT <= 11'd0;

////////////////////////////////////////////////////////////////////////////////////////////////////////////   
/////////////////////////////////////////// ICMP ///////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
ICMP_DECODER ICMP_DECODER_inst
(
.RST                    	(RST),   
.CLK                    	(CLK),     							// RX_CLK
// ICMP ������
.ICMP_EN                	(ICMP_EN),
.ICMP_HEADER                (ICMP_HEADER), // 68'b0
.ICMP_DATA_REQ		        (ICMP_TX_DATA_REQ),		//  I
.ICMP_DONE			        (ICMP_DONE),		//  O
.ICMP_TYPE                  (ICMP_TYPE),

.IN_DATA       				(IN_DATA),        				//  [7:0]
.IN_DATA_VLD   				(IN_DATA_VLD),

.ICMP_DATA                  (ICMP_TX_DATA),				
.ICMP_DATA_VLD              (ICMP_TX_DATA_VLD)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////   
/////////////////////////////////////////// UDP ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
UDP_DECODER	
#(
.HTGv6_UDP_PORT    (HTGv6_UDP_PORT)
)
UDP_DECODER_inst
(
.RST				    (RST),
.CLK					(CLK),

.IN_DATA				(IN_DATA),
.IN_DATA_VLD			(IN_DATA_VLD),

.UDP_EN			      	(UDP_EN),
.UDP_HEADER             (UDP_HEADER),
.UDP_DONE				(UDP_DONE),
.UDP_TYPE               (UDP_TYPE),
// UDP ������
.UDP_DATA_VLD			(UDP_DATA_VLD),
.UDP_DATA				(UDP_DATA) 			// [71:0]
    );
/*
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// ������� CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [35:0] CONTROL0;
	    
	     chipscope_icon_v1_06_a_0 ICON
	(	    .CONTROL0			(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILA
	(
	    .CONTROL	    (CONTROL0), // INOUT BUS [35:0]
	    .CLK			(CLK), // IN
	    
	    .TRIG0			({43'b0,ICMP_TX_DATA_REQ,ICMP_TX_DATA,ICMP_TX_DATA_VLD,ICMP_DONE,ICMP_EN,IP_ST,IP_TYPE,IP_DONE,IP_EN}), // IN BUS [63:0]
	    .TRIG1			(ICMP_HEADER[63:0]) // IN BUS [63:0]
	);
*/		
endmodule