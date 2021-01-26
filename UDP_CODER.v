`timescale 1ns / 1ps

/*
UDP_CODER	
#(
.HTGv6_UDP_PORT    ()
)
UDP_CODER_inst
(
.RST							(),
.CLK							(),
.UDP_EN					(),
.UDP_DONE				(),

.IN_DATA					(),		// [7:0]
.IN_DATA_VLD		(),
// UDP данные
.UDP_DATA_REQUEST		(),
.IN_DATA_CHECKSUM		(),
.IN_DATA_LENGTH			(),
.UDP_DST_PORT				(),
.UDP_DATA						() // [7:0]
    );
*/
// Кодер входных пакетов UDP
module UDP_CODER
#(
parameter HTGv6_UDP_PORT    = 16'd10_002		// Димон так сказал
)
(
input 					RST,
input 					CLK,     // RX_CLK

input 					UDP_EN,
input [8*8-1:0]         UDP_HEADER,

input [7:0]	 	        IN_DATA,					// Данные, которые хочет передать пользователь
input 					IN_DATA_VLD,
input [15:0]			IN_DATA_LENGTH,
// UDP данные
output reg 			    UDP_DATA_REQUEST,
input [15:0]			UDP_DATA_CHECKSUM,
input [15:0]            UDP_PSEUDO_HEADER_CHECKSUM,

output reg [7:0] 		UDP_DATA,
output reg				UDP_DONE
);
localparam UDP_HDR_BYTE0_ST 	 = 4'b0001;
localparam UDP_HDR_BYTE1_ST 	 = 4'b0011;
localparam UDP_HDR_BYTE2_ST 	 = 4'b0010;
localparam UDP_HDR_BYTE3_ST 	 = 4'b0110;
localparam UDP_HDR_BYTE4_ST 	 = 4'b0111;
localparam UDP_HDR_BYTE5_ST 	 = 4'b0101;
localparam UDP_HDR_BYTE6_ST 	 = 4'b0100;
localparam UDP_HDR_BYTE7_ST 	 = 4'b1100;
localparam UDP_DATA_ST 			 = 4'b1101;
localparam UDP_DONE_ST 			 = 4'b1001;


wire [15:0]		UDP_DST_PORT;
wire [15:0] 	UDP_SRC_PORT;
wire [15:0] 	UDP_DST_TEST_PORT;
wire [15:0] 	UDP_LENGTH;
reg  [19:0]     UDP_CHECKSUM;
reg  [15:0]     UDP_OUT_CHECKSUM;

(* fsm_encoding = "gray" *) 
reg [3:0] UDP_ST;

assign UDP_DST_PORT         = UDP_HEADER[15:0];   
assign UDP_DST_TEST_PORT    = 16'd10003;
assign UDP_SRC_PORT         = HTGv6_UDP_PORT;
assign UDP_LENGTH           = IN_DATA_LENGTH + 16'd8;


always @(posedge CLK or posedge RST)
if (RST)
	begin
		UDP_ST			   <= UDP_HDR_BYTE0_ST;
     	UDP_DATA_REQUEST    <= 0;
     	UDP_DATA		   <= 0;
		UDP_DONE		   <= 0;
		UDP_OUT_CHECKSUM   <= 0;
	end
else 
(* parallel_case *)(* full_case *)
case (UDP_ST)
// Формирование данных  UDP_SRC_PORT
UDP_HDR_BYTE0_ST:		begin 
												UDP_DATA					<= UDP_SRC_PORT[15:8];
												UDP_DONE 					<= 0;
											if (UDP_EN)		
												UDP_ST						<= UDP_HDR_BYTE1_ST;
											else
												UDP_ST						<= UDP_HDR_BYTE0_ST;		
										end
UDP_HDR_BYTE1_ST:		begin											
												UDP_DATA					<= UDP_SRC_PORT[7:0];
												UDP_ST						<= UDP_HDR_BYTE2_ST;
										end
// Формирование данных  UDP_DST_PORT
UDP_HDR_BYTE2_ST:		begin											
												UDP_DATA					<= /*UDP_DST_TEST_PORT[15:8];//*/UDP_DST_PORT[15:8];
												UDP_ST						<= UDP_HDR_BYTE3_ST;
										end
UDP_HDR_BYTE3_ST:		begin											                                                        										
												UDP_DATA					<= /*UDP_DST_TEST_PORT[7:0];//*/UDP_DST_PORT[7:0];                                             									
												UDP_ST						<= UDP_HDR_BYTE4_ST;                                               									
										end                                                                              									
// Формирование данных  UDP_LENGTH                                                             									
UDP_HDR_BYTE4_ST:		begin											                                                        										
												UDP_DATA					<= UDP_LENGTH[15:8];                                             									
												UDP_ST						<= UDP_HDR_BYTE5_ST;                                               									
										end 
UDP_HDR_BYTE5_ST:		begin											                                                        										
												UDP_DATA					<= UDP_LENGTH[7:0];                                                											
												UDP_ST						<= UDP_HDR_BYTE6_ST;  
												UDP_OUT_CHECKSUM            <=~(UDP_CHECKSUM[15:0] + {12'b0,UDP_CHECKSUM[19:16]});
										end                                                                              										
// Формирование данных  UDP_CHECKSUM                                                             				
UDP_HDR_BYTE6_ST:		begin											                                                         
												UDP_DATA					<= UDP_OUT_CHECKSUM[15:8];                                                 	
												UDP_ST						<= UDP_HDR_BYTE7_ST;  
												UDP_DATA_REQUEST	<= 1;   
										end                                                                               
UDP_HDR_BYTE7_ST:		begin											                                                        	
												UDP_DATA					<= UDP_OUT_CHECKSUM[7:0];                                                 			
												UDP_ST						<= UDP_DATA_ST;
												UDP_DATA_REQUEST	<= 0; 
										end                                                                              	
// Формирование выходных данных 
UDP_DATA_ST:			begin
											if (IN_DATA_VLD)
											begin											                                                        	  
												UDP_DATA					<= IN_DATA;                                                			 
												UDP_ST						<= UDP_DATA_ST;   
											end   
										else 
											begin
												UDP_DATA					<= 0;
												UDP_ST						<= UDP_DONE_ST;
												UDP_DONE		   			<= 1;
											end	
									end			                                                                           	  
UDP_DONE_ST:				begin											                                                        	      
												UDP_ST						<= UDP_HDR_BYTE0_ST; 
												UDP_OUT_CHECKSUM            <= 0;
												UDP_DONE		   			<= 0;                                            
											end        
default:								begin
												UDP_ST			   			<= UDP_HDR_BYTE0_ST;
												UDP_OUT_CHECKSUM            <= 0;
   											    UDP_DATA_REQUEST		    <= 0;
     											UDP_DATA		  		    <= 0;
												UDP_DONE		   			<= 0;
										end
endcase											                                                                    

always @(*)
begin
    UDP_CHECKSUM = UDP_SRC_PORT + /*UDP_DST_TEST_PORT*/ UDP_DST_PORT + UDP_LENGTH + UDP_DATA_CHECKSUM + UDP_PSEUDO_HEADER_CHECKSUM;
end



//assign  UDP_CHECKSUM = UDP_SRC_PORT + /*UDP_DST_TEST_PORT*/ UDP_DST_PORT + UDP_LENGTH + UDP_DATA_CHECKSUM + UDP_PSEUDO_HEADER_CHECKSUM;

/*				
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// Отладка CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [35:0] CONTROL0;
	    
	     chipscope_icon_v1_06_a_0 ICON
	(	    .CONTROL0			(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILAz
	(
	    .CONTROL	(CONTROL0), // INOUT BUS [35:0]
	    .CLK				(CLK), // IN
	    
	    .TRIG0			({63'b0,UDP_EN}), // IN BUS [63:0]
	    .TRIG1			({48'b0,UDP_LENGTH}), // IN BUS [63:0]
	    .TRIG2			({UDP_PSEUDO_HEADER_CHECKSUM,UDP_DATA_CHECKSUM,UDP_DST_PORT,UDP_SRC_PORT}), // IN BUS [63:0]
	    .TRIG3			(64'b0) // IN BUS [63:0]
	);
*/
endmodule											          