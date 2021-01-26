`timescale 1ns / 1ps

/*
����� �������� ������ Ethernet.
������ ������ �� ��� ��� �����������. ������ �� ���, ����� �� ����������� ���������� � ������������� ���������� ���� �������� �������� � ������
*/
/*

*/

module DATA_DOZATOR_v2
//#(
//parameter MAX_LENGTH	= 16'd1450 	// ������������ ����� �� ��������� 1500 - ����� ���������� (42 �����), ����� ������� ��������
//)
(
input           RST,
input [2:0]     LENGTH_CODE,

input 			IN_DATA_CLK,
input [15:0] 	IN_DATA,										// ����� ������ ������ �� ���
input 		 	IN_DATA_VLD,
input 			IN_DATA_PRECENCE,					// ���� ����, ��� ����������, �� �������� ������� ������,�� �������� �������� ������. ����� ��� ������ �������������� �������� ������ ������ � ���������� �������� ������
output reg		IN_DATA_FLOW_PAUSE,

input 			OUT_DATA_CLK,
output reg [7:0]OUT_DATA,
output reg		OUT_DATA_VLD,
output reg		OUT_DATA_RDY,					// �������� �����������, ��� � ���� ���������� ������ � �� ���������� ���������
input 			OUT_DATA_REQUEST,		// ���������� ������� � ���������, ����� ���������� � ������������ ����� �������� ������

output reg [15:0]	PACKET_NUMBER,				// ���������� ����� ������������ �������
output reg [15:0]	OUT_DATA_LENGTH,			// ���������� ����������� ����
output reg [15:0]	OUT_DATA_CHECKSUM		// ����������� ����� ������
);


localparam IDLE_WR_ST		= 6'b000001;
localparam WREN_ST		    = 6'b000010;
localparam WR_SUMMARY_ST    = 6'b000100;   // � ����� ��������� ������������� �������� ������ ��� ����� PACKET_NUMBER, OUT_DATA_LENGTH, OUT_DATA_CHECKSUM
localparam WR_DONE_ST		= 6'b001000;

localparam IDLE_RD_ST		= 8'b11111110;
localparam RD_SIZE_0_ST     = 8'b11111101;
localparam RD_SIZE_1_ST     = 8'b11111011;
localparam RD_SIZE_2_ST     = 8'b11110111;
localparam RD_SIZE_3_ST     = 8'b11101111;
localparam RDEN_ST    		= 8'b11011111;
localparam RD_DONE_ST  		= 8'b10111111;
localparam RST_ST     		= 8'b01111111;


(* fsm_encoding = "gray" *)
reg [5:0]	WR_ST;
reg [9:0]   WR_ADDR;     // ������� ����! �� ������ �� ��� ����� �� ������, � ������� ������ �� �����, ������ CNT �������� �� 2, ����� �������� ���������� ���������� ����
reg         WR_DONE;    // ������ ��������, ������ ���������� ������ ���� ������ ������� ��������

reg [7:0]	RD_ST;
reg [10:0]  RD_ADDR;     // ����� ��� ������� �� ������ �����, ������ ��� OUT_DATA � ��� [7:0]
reg         RD_DONE;    // ������ ��������� ����������� ������
wire [15:0] RAM_DATA;

reg [10:0]  MAX_LENGTH;
reg [26:0]  IN_DATA_SUM_0;
reg [16:0]  IN_DATA_SUM_1;

always @(posedge IN_DATA_CLK or posedge RST)
if (RST)    MAX_LENGTH <= 11'd1458;     // �� ������� ������ ������ ������������
else case (LENGTH_CODE)
3'b000:     MAX_LENGTH <= 11'd1458;
3'b001:     MAX_LENGTH <= 11'd1024;
3'b010:     MAX_LENGTH <= 11'd512;
3'b011:     MAX_LENGTH <= 11'd256;
3'b100:     MAX_LENGTH <= 11'd128;
3'b101:     MAX_LENGTH <= 11'd64;
default:    MAX_LENGTH <= 11'd1458;
endcase

always @(posedge IN_DATA_CLK or posedge RST)
if(RST)
    begin
        WR_ST               <= IDLE_WR_ST;
        WR_ADDR             <= 10'b0;
        WR_DONE             <= 1'b0;
        IN_DATA_FLOW_PAUSE  <= 1'b0;
        IN_DATA_SUM_0       <= 27'b0;
        IN_DATA_SUM_1       <= 17'b0;
        OUT_DATA_CHECKSUM   <= 16'b0;
        OUT_DATA_LENGTH     <= 16'b0;
        
        PACKET_NUMBER       <= 16'b0;
    end
else 
(* parallel_case *)(* full_case *)
case (WR_ST)
IDLE_WR_ST: if (IN_DATA_PRECENCE && IN_DATA_VLD)
                begin
                    WR_ST               <= WREN_ST;
                    WR_ADDR             <= WR_ADDR + 1'b1;
                    IN_DATA_SUM_0       <= {11'b0,IN_DATA};
                end
             else     
                begin
                    WR_ST               <= IDLE_WR_ST;
                    WR_ADDR             <= 10'b0;
                    PACKET_NUMBER       <= 16'b0;
                    IN_DATA_SUM_0       <= 27'b0;
                end
WREN_ST:if (IN_DATA_VLD)
            begin
               if (WR_ADDR >= MAX_LENGTH/2 - 2'd2)    
                begin
                    IN_DATA_SUM_0       <= IN_DATA_SUM_0 + {11'b0,IN_DATA};
                    IN_DATA_FLOW_PAUSE  <= 1'b1;
                    WR_ST               <= WREN_ST;
                    WR_ADDR             <= WR_ADDR + 1'b1;
                end    
               else
                begin
                    IN_DATA_SUM_0       <= IN_DATA_SUM_0 + {11'b0,IN_DATA};
                    IN_DATA_FLOW_PAUSE  <= 1'b0;
                    WR_ST               <= WREN_ST;
                    WR_ADDR             <= WR_ADDR + 1'b1;
                end
            end
         else 
            begin
                WR_ST               <= WR_SUMMARY_ST;
                WR_ADDR             <= WR_ADDR;  
                IN_DATA_SUM_0       <= IN_DATA_SUM_0;// + {11'b0,IN_DATA};
                IN_DATA_FLOW_PAUSE  <= 1'b1;
            end   
WR_SUMMARY_ST:            
            begin
                WR_ST               <= WR_DONE_ST;
                IN_DATA_SUM_0       <= IN_DATA_SUM_0;
                OUT_DATA_LENGTH     <= {5'b0,(WR_ADDR + 10'd2),1'b0};
                PACKET_NUMBER       <= PACKET_NUMBER + 1'b1;
                IN_DATA_SUM_1       <= {6'b0,(WR_ADDR + 10'd2),1'b0} + {1'b0,IN_DATA_SUM_0[15:0]} + {6'b0,IN_DATA_SUM_0[26:16]};
            end
WR_DONE_ST:if (RD_DONE)
            begin
                WR_ST               <= IDLE_WR_ST;
                WR_ADDR             <= 10'b0;  
                WR_DONE             <= 1'b0;
                IN_DATA_FLOW_PAUSE  <= 1'b0;
                IN_DATA_SUM_0       <= 27'b0;
                IN_DATA_SUM_1       <= 17'b0;
                OUT_DATA_CHECKSUM   <= 16'b0;
            end 
           else 
            begin
                WR_ST               <= WR_DONE_ST;
                WR_DONE             <= 1'b1;
                OUT_DATA_CHECKSUM   <= IN_DATA_SUM_1[15:0] + {15'b0,IN_DATA_SUM_1[16]};
            end          

default:    begin
                WR_ST               <= IDLE_WR_ST;
                WR_ADDR             <= 10'b0;  
                WR_DONE             <= 1'b0;
                IN_DATA_FLOW_PAUSE  <= 1'b0;
                IN_DATA_SUM_0       <= 27'b0;
                IN_DATA_SUM_1       <= 17'b0;
                OUT_DATA_CHECKSUM   <= 16'b0;
            end 
endcase



always @(posedge OUT_DATA_CLK or posedge RST)
if (RST)
    begin
        RD_ST               <= IDLE_RD_ST;
        RD_ADDR             <= 11'b0;
        RD_DONE             <= 1'b0;
        
        OUT_DATA            <= 8'b0;
        OUT_DATA_VLD        <= 1'b0;    
        OUT_DATA_RDY        <= 1'b0;				
    end
else 
(* parallel_case *)(* full_case *)
case (RD_ST)
IDLE_RD_ST:   if (WR_DONE)
                begin
                    if (OUT_DATA_REQUEST) 
                        begin
                            RD_ST           <= RD_SIZE_0_ST;
                            OUT_DATA_RDY    <= 1'b0;
                            OUT_DATA_VLD    <= 1'b1; 
                            OUT_DATA        <= 8'b0;
                        end
                    else 
                        begin
                            RD_ST           <= IDLE_RD_ST;
                            OUT_DATA_RDY    <= 1'b1; 
                            OUT_DATA_VLD    <= 1'b0; 
                        end
                 end    
              else 
                begin
                    RD_ST           <= IDLE_RD_ST;
                    OUT_DATA_RDY    <= 1'b0;    
                end                     
RD_SIZE_0_ST:
                begin
                    RD_ST           <= RD_SIZE_1_ST;
                    OUT_DATA        <= 8'b0;
                end
RD_SIZE_1_ST:
                begin
                    RD_ST           <= RD_SIZE_2_ST;
                    OUT_DATA        <= OUT_DATA_LENGTH[15:8];
                end
RD_SIZE_2_ST:
                begin
                    RD_ST           <= RD_SIZE_3_ST;
                    OUT_DATA        <= OUT_DATA_LENGTH[7:0];
                    RD_ADDR         <= RD_ADDR + 1'b1;
                end                                
RD_SIZE_3_ST:
                begin
                    RD_ST           <= RDEN_ST;
                    OUT_DATA        <= RAM_DATA; 
                    RD_ADDR         <= RD_ADDR + 1'b1;
                end

RDEN_ST: if (RD_ADDR  >= (WR_ADDR)*2 + 1'b1)
            begin
                RD_ST               <= RST_ST;
                RD_ADDR             <= RD_ADDR;
                OUT_DATA_VLD        <= 1'b0; 
                OUT_DATA            <= OUT_DATA;
            end
         else
            begin
                RD_ST               <= RDEN_ST;
                OUT_DATA            <= RAM_DATA;
                RD_ADDR             <= RD_ADDR + 1'b1;
            end

RST_ST: begin
            RD_ST               <= RD_DONE_ST;
            RD_DONE             <= 1'b1;
        end     
 
RD_DONE_ST: begin
                RD_ST               <= IDLE_RD_ST;
                RD_ADDR             <= 11'b0;
                RD_DONE             <= 1'b0;
            end 

default:    begin
                RD_ST               <= IDLE_RD_ST;
                RD_ADDR             <= 11'b0;
                RD_DONE             <= 1'b0;
                
                OUT_DATA            <= 8'b0;
                OUT_DATA_VLD        <= 1'b0;    
                OUT_DATA_RDY        <= 1'b0;				
            end
endcase
	
 DOZATOR_RAM DOZATOR_RAM
  (
  .clka     (IN_DATA_CLK), // input clka
  .wea      (IN_DATA_VLD), // input [0 : 0] wea
  .addra    (WR_ADDR), // input [9 : 0] addra
  .dina     ({IN_DATA[7:0],IN_DATA[15:8]}),//IN_DATA), // input [15 : 0] dina
  
  .clkb     (OUT_DATA_CLK), // input clkb
  .addrb    (RD_ADDR), // input [10 : 0] addrb
  .doutb    (RAM_DATA) // output [7 : 0] doutb
);
	

/*
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// ������� CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [35:0] CONTROL0;
	    
	     chipscope_icon_v1_06_a_0 ICON
	(	.CONTROL0	(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILA
	(
	    .CONTROL	    (CONTROL0),    // INOUT BUS [35:0]
	    .CLK		    (IN_DATA_CLK),         // IN
	    
	    .TRIG0			({14'b0,IN_DATA_SUM_1,WR_ADDR,WR_ST,IN_DATA,WR_DONE,IN_DATA_FLOW_PAUSE,IN_DATA_VLD,IN_DATA_PRECENCE}), // IN BUS [63:0]
	    .TRIG1			({10'b0,IN_DATA_SUM_0,OUT_DATA,RD_ADDR,RD_ST,RD_DONE,RD_EN,OUT_DATA_REQUEST,OUT_DATA_VLD,OUT_DATA_RDY}) // IN BUS [63:0]
	);
*/	
	
endmodule
