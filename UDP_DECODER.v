`timescale 1ns / 1ps



/*
UDP_DECODER	UDP_DECODER_inst
#(
.HTGv6_UDP_PORT    ()
)
(
.RST							(),
.CLK							(),

.IN_DATA					    (),
.IN_DATA_VLD		            (),
// Заголовок и флаги обработки UDP
.UDP_EN					        (),
.UDP_HEADER                     (), //[8*8-1:0]
.UDP_DONE				        (),
// UDP данные
.UDP_DATA_VLD		            (),
.UDP_DATA				        () // [71:0]
);
*/

// Декодер входных пакетов UDP

`define UNSUPPORTED_TYPE_MES 2'b00
`define VALID_UDP_TYPE_MES   2'b01  // Типа да, это сообщение UDP и оно адресовано нам

module UDP_DECODER
#(
parameter HTGv6_UDP_PORT    = 16'd10_002		// Димон так сказал
)
(
input 				RST,
input 				CLK,     // RX_CLK

input 		[7:0]	IN_DATA,
input 				IN_DATA_VLD,
// Заголовок и флаги обработки UDP
input 				  UDP_EN,
output reg [8*8*-1:0] UDP_HEADER,
output reg			  UDP_DONE,
output reg [1:0]      UDP_TYPE,
// UDP данные
output reg			UDP_DATA_VLD,
output reg [71:0] 	UDP_DATA
);
localparam UDP_HDR_BYTE0_ST	 = 5'b00001;
localparam UDP_HDR_BYTE1_ST	 = 5'b00011;
localparam UDP_HDR_BYTE2_ST	 = 5'b00010;
localparam UDP_HDR_BYTE3_ST	 = 5'b00110;
localparam UDP_HDR_BYTE4_ST	 = 5'b00111;
localparam UDP_HDR_BYTE5_ST	 = 5'b00101;
localparam UDP_HDR_BYTE6_ST	 = 5'b00100;
localparam UDP_HDR_BYTE7_ST	 = 5'b01100;
localparam UDP_DATA_BYTE0_ST = 5'b01101;
localparam UDP_DATA_BYTE1_ST = 5'b01001;
localparam UDP_DATA_BYTE2_ST = 5'b01011;
localparam UDP_DATA_BYTE3_ST = 5'b01111;
localparam UDP_DATA_BYTE4_ST = 5'b01110;
localparam UDP_DATA_BYTE5_ST = 5'b01010;
localparam UDP_DATA_BYTE6_ST = 5'b01000;
localparam UDP_DATA_BYTE7_ST = 5'b11000;
localparam UDP_DATA_BYTE8_ST = 5'b11001;
localparam UDP_DONE_ST 		 = 5'b10001;

reg [15:0]  UDP_SRC_PORT_reg;
reg [15:0]  UDP_SRC_PORT;
reg [15:0] 	UDP_DST_PORT;
reg [15:0] 	UDP_LENGTH;
reg [15:0] 	UDP_CHECKSUM;
reg [71:0]  UDP_DATA_reg; 

(* fsm_encoding = "gray" *)
reg [4:0] UDP_ST;
reg MES_RCV;        // Принято сообщение

always @(posedge CLK or posedge RST)
if (RST)
	begin
		UDP_ST		      <= UDP_HDR_BYTE0_ST;
		
		UDP_SRC_PORT_reg  <= 16'b0;
		UDP_SRC_PORT      <= 16'b0;
     	UDP_DST_PORT      <= 16'b0;
     	UDP_LENGTH 	      <= 16'b0;
     	UDP_CHECKSUM      <= 16'b0;
     	
     	UDP_HEADER        <= 64'b0;
     	UDP_DONE	      <= 1'b0;
     	UDP_TYPE          <= 0;
     	
 		UDP_DATA_reg	  <= 72'b0;
 		MES_RCV           <= 1'b0;
	end
else 
(* parallel_case *)(* full_case *)
case (UDP_ST)
// Прием данных  UDP_SRC_PORT
UDP_HDR_BYTE0_ST:			if (UDP_EN)		
								begin
									UDP_SRC_PORT_reg[15:8]<= IN_DATA;
									UDP_ST				  <= UDP_HDR_BYTE1_ST;
								end	
							else	UDP_ST				  <= UDP_HDR_BYTE0_ST;
UDP_HDR_BYTE1_ST:		begin											
							UDP_SRC_PORT_reg[7:0] 	      <= IN_DATA;
							UDP_ST						  <= UDP_HDR_BYTE2_ST;
						end
// Прием данных  UDP_DST_PORT
UDP_HDR_BYTE2_ST:		begin											
							UDP_DST_PORT[15:8] 	          <= IN_DATA;
							UDP_ST						  <= UDP_HDR_BYTE3_ST;
						end
UDP_HDR_BYTE3_ST:		begin											                                                        										
							UDP_DST_PORT[7:0] 	          <= IN_DATA;                                                									
							UDP_ST						  <= UDP_HDR_BYTE4_ST;                                               									
						end                                                                              									
// Прием данных  UDP_LENGTH                                                             									
UDP_HDR_BYTE4_ST:		if (UDP_DST_PORT == HTGv6_UDP_PORT)		// Проверяем к нам-ли пришел пакет
							begin
						      UDP_SRC_PORT                <= UDP_SRC_PORT_reg;											                                                         									
							  UDP_LENGTH[15:8] 		      <= IN_DATA;                                                 									
							  UDP_ST					  <= UDP_HDR_BYTE5_ST;                                                									
							end  
						else 
							begin
							     UDP_DONE	       <= 1'b1;
								 UDP_TYPE          <= `UNSUPPORTED_TYPE_MES;
							     if (IN_DATA_VLD)	UDP_ST      <= UDP_HDR_BYTE4_ST;
								 else				UDP_ST      <= UDP_DONE_ST; 
							end		
UDP_HDR_BYTE5_ST:		begin											                                                        										
							UDP_LENGTH[7:0] 		      <= IN_DATA;                                                											
							UDP_ST						  <= UDP_HDR_BYTE6_ST;                                               										
						end                                                                              										
// Прием данных  UDP_CHECKSUM                                                             				
UDP_HDR_BYTE6_ST:		begin											                                                         
							UDP_CHECKSUM[15:8]            <= IN_DATA;                                                 	
							UDP_ST						  <= UDP_HDR_BYTE7_ST;                                                
						end                                                                               
UDP_HDR_BYTE7_ST:		begin											                                                        	
							UDP_CHECKSUM[7:0] 	          <= IN_DATA;                                                			
							UDP_ST						  <= UDP_DATA_BYTE0_ST;                                               	
						end                                                                              	
// Прием адреса назначения для данных
UDP_DATA_BYTE0_ST:	if (IN_DATA_VLD)
						begin											                                                        	  
							UDP_DATA_reg[71:64] 		  <= IN_DATA;  
							MES_RCV                       <= 1'b0;                                              			 
							UDP_ST						  <= UDP_DATA_BYTE1_ST;    
						end   
					else 
						begin
							UDP_ST						  <= UDP_DONE_ST;
							MES_RCV                       <= 1'b0;
							UDP_DONE		   			  <= 1'b1;
							UDP_DATA_reg		   		  <= 72'b0;
						end		                                                                           	  
// Прием данных
UDP_DATA_BYTE1_ST:	if (IN_DATA_VLD)
						begin											                                                        	  
							UDP_DATA_reg[63:56] 		  <= IN_DATA;                                                			 
							UDP_ST						  <= UDP_DATA_BYTE2_ST;                                               	 
						end   
					else 
						begin
							UDP_ST						  <= UDP_DONE_ST;
							UDP_DONE		   			  <= 1'b1;
							UDP_TYPE                      <= `VALID_UDP_TYPE_MES;
							UDP_DATA_reg		   		  <= 72'b0;
						end	
UDP_DATA_BYTE2_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
							UDP_DATA_reg[55:48] 		  <= IN_DATA;                                                	
							UDP_ST						  <= UDP_DATA_BYTE3_ST;                                             
					    end                                                                            
					else                                                                            
						begin                                                                          
							UDP_ST						  <= UDP_DONE_ST;  
							UDP_DONE		   			  <= 1'b1;         
							UDP_TYPE                      <= `VALID_UDP_TYPE_MES;
							UDP_DATA_reg		   		  <= 72'b0;                                           
						end	                                                                           
UDP_DATA_BYTE3_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
							UDP_DATA_reg[47:40] 		  <= IN_DATA;                                                	
							UDP_ST						  <= UDP_DATA_BYTE4_ST;                                             
						end                                                                            
					else                                                                            
						begin                                                                          
					   	  UDP_ST						  <= UDP_DONE_ST;  
						  UDP_DONE		   			      <= 1'b1; 
						  UDP_TYPE                        <= `VALID_UDP_TYPE_MES;      
						  UDP_DATA_reg		   			  <= 72'b0;                                             
						end	                                                                           
UDP_DATA_BYTE4_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
						  UDP_DATA_reg[39:32] 		      <= IN_DATA;                                                	
						  UDP_ST						  <= UDP_DATA_BYTE5_ST;                                             
						end                                                                            
					else                                                                            
						begin                                                                          
						  UDP_ST						  <= UDP_DONE_ST;   
						  UDP_DONE		   			      <= 1'b1;     
					      UDP_TYPE                        <= `VALID_UDP_TYPE_MES;
					      UDP_DATA_reg		   			  <= 72'b0;                                              
						end	                                                                           
UDP_DATA_BYTE5_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
					      UDP_DATA_reg[31:24] 		      <= IN_DATA;                                                	
						  UDP_ST						  <= UDP_DATA_BYTE6_ST;                                             
						end                                                                            
					else                                                                            
						begin                                                                          
						  UDP_ST						  <= UDP_DONE_ST;   
						  UDP_DONE		   			      <= 1'b1;           
						  UDP_TYPE                        <= `VALID_UDP_TYPE_MES;
						  UDP_DATA_reg		   			  <= 72'b0;                                        
						end	                                                                           
UDP_DATA_BYTE6_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
						  UDP_DATA_reg[23:16] 		      <= IN_DATA;                                                	
						  UDP_ST						  <= UDP_DATA_BYTE7_ST;                                             
						end                                                                            
					else                                                                            
						begin                                                                          
						  UDP_ST						  <= UDP_DONE_ST; 
						  UDP_DONE		   			      <= 1'b1;        
						  UDP_TYPE                        <= `VALID_UDP_TYPE_MES;
						  UDP_DATA_reg		   			  <= 72'b0;                                             
						end	                                                                           
UDP_DATA_BYTE7_ST:	if (IN_DATA_VLD)                                                       
						begin											                                                        	      
					      UDP_DATA_reg[15:8] 			  <= IN_DATA;      
						  UDP_ST						  <= UDP_DATA_BYTE8_ST;   
						end                                                                            
					else                                                                            
						begin                                                                          									
						  UDP_ST						  <= UDP_DONE_ST;   
						  UDP_DONE		   			      <= 1'b1;       
						  UDP_TYPE                        <= `VALID_UDP_TYPE_MES;
						  UDP_DATA_reg		   			  <= 72'b0;                                           
						end	                                                                 
UDP_DATA_BYTE8_ST:     if (IN_DATA_VLD)                                                       
						  begin											                                                        	      
						      UDP_DATA_reg[7:0] 			  <= IN_DATA;
						      UDP_ST						  <= UDP_DATA_BYTE0_ST;
						      MES_RCV                         <= 1'b1;
						  end                                                                            
					   else                                                                            
						  begin                                                                          
						      UDP_ST						  <= UDP_DONE_ST; 
						      UDP_DATA_reg					  <= UDP_DATA_reg;       
						      UDP_DONE		   			      <= 1'b1;
						      UDP_TYPE                        <= `VALID_UDP_TYPE_MES;                                              
						  end	   
UDP_DONE_ST:		begin											                                                        	      
					      UDP_DATA_reg 					  <= 72'b0;
					      UDP_HEADER                      <= {UDP_CHECKSUM,UDP_LENGTH,UDP_DST_PORT,UDP_SRC_PORT};  

						  UDP_DONE		   			      <= 1'b0;
                          UDP_ST	                      <= UDP_HDR_BYTE0_ST;   // должны сразу переходить в состояние ожидания   
                            
                          MES_RCV                         <= 1'b0;  
                          if (IN_DATA_VLD) 	  UDP_ST	  <= UDP_DONE_ST;		
                          else          	  UDP_ST	  <= UDP_HDR_BYTE0_ST;                                            
					end      
default:
    begin
        UDP_ST		      <= UDP_HDR_BYTE0_ST;
    		
        UDP_SRC_PORT_reg  <= 16'b0;    		
        UDP_SRC_PORT      <= 16'b0;
        UDP_DST_PORT      <= 16'b0;
        UDP_LENGTH 	      <= 16'b0;
        UDP_CHECKSUM      <= 16'b0;
         	
        UDP_HEADER        <= UDP_HEADER;
        UDP_DONE	      <= 1'b0;
    	
     	UDP_DATA_reg      <= 72'b0;
    end					
					
					  
endcase											                                                                    

always @(posedge CLK or posedge RST)
if (RST)
    begin
        UDP_DATA	      <= 72'b0;
        UDP_DATA_VLD      <= 1'b0;
    end
else if (MES_RCV)  
    begin
        if (UDP_DATA_reg == 72'b0)
            begin
                UDP_DATA	      <= 72'b0;
                UDP_DATA_VLD      <= 1'b0;
            end
        else
            begin
                UDP_DATA	      <= UDP_DATA_reg;
                UDP_DATA_VLD      <= 1'b1;
            end        
    end
else   
    begin
        UDP_DATA	      <= UDP_DATA;
        UDP_DATA_VLD      <= 1'b0;
    end   

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
	    
	    .TRIG0			({UDP_DATA[62:0],IN_DATA_VLD}), // IN BUS [63:0]
	    .TRIG1			({49'b0,UDP_ST,UDP_DATA_VLD,UDP_DATA[71:63]}) // IN BUS [63:0]
	);
*/

endmodule											          