`timescale 1ns / 1ps

/*
CLIENT_MAC_RX CLIENT_MAC_RX
(
.RST                    (),
// FROM EMAC
.EMAC_RXDATA            (),   //  [7:0] ����������� ������ �� MAC ����
.EMAC_RXDATA_VLD        (),   //  ���������� ����������� ������ 
.EMAC_RXCLK             (),	  //  �������� ������� ����������� ������ �� MAC ���� 
.EMAC_RXSTATS           (),   // [6:0] ���������� �� ��������� �������� �����. 28 ������ ������ ���������� ��������������� �� 7 ��� �� ����  
.EMAC_RXSTATSVLD        (),   // ���������� �������������� ������ ���������
.EMAC_RXSTATSBYTEVLD    (),	
// FROM CLIENT
.CLIENT_CLK             (),
.CLIENT_DATA            (),
.CLIENT_DATA_VLD        (),
.RX_STOP                (),   // ���������������� ����� ��������� ��� ���� ����� ��������� �������� ��������� ������
.RX_RST                 ()    // ���� �������� ��������, ��� ����������� ��������� ��� �� ��������
);
*/

//������ ������ ������ �� ���� EMAC ����� ��������� �� 2048 ���� ������ ��������������. ������ FIFO 2048 � 8 

module CLIENT_MAC_RX
(
input       RST,
// FROM EMAC
input [7:0] EMAC_RXDATA,   	   //  [7:0] ����������� ������ �� MAC ����
input 		EMAC_RXDATA_VLD,   //  ���������� ����������� ������ 
input 		EMAC_RXCLK,		   //  �������� ������� ����������� ������ �� MAC ���� 
input [6:0] EMAC_RXSTATS,      // [6:0] ���������� �� ��������� �������� �����. 28 ������ ������ ���������� ��������������� �� 7 ��� �� ����  
input       EMAC_RXSTATSVLD,   // ���������� �������������� ������ ���������
input       EMAC_RXSTATSBYTEVLD,	
// FROM CLIENT
input 		CLIENT_CLK,
output[7:0]	CLIENT_DATA,
output reg	CLIENT_DATA_VLD,
input       RX_STOP,                // ���������������� ����� ��������� ��� ���� ����� ��������� �������� ��������� ������
input       RX_RST                  // ���� �������� ��������, ��� ����������� ��������� ��� �� ��������
);

//localparam IDLE_ST 	        = 2'b001;
//localparam FIFO_WREN_ST 	= 2'b011;
//localparam FIFO_RDEN_ST 	= 2'b010;

parameter [1:0]     IDLE_ST      =   2'b01,
                    FIFO_WREN_ST =   2'b11,
                    FIFO_RDEN_ST =   2'b10;

(*fsm_encoding = "gray"*)
reg [1:0] 		ST;			// ��������� , ����� ������������ ������ ������ �� ����
wire[10:0] 	    RD_DATA_CNT;
reg             FIFO_RDEN;
reg             FIFO_RST;

reg [7:0] EMAC_DATA;
reg       EMAC_VLD;

fifo_mac_rx RX_FIFO 
(
  .rst		    			(FIFO_RST || RST), // input rst
  //MAC side
  .wr_clk					(EMAC_RXCLK), // input wr_clk
  .din						(EMAC_DATA), // input [7 : 0] din
  .wr_en					(EMAC_VLD), // input wr_en
  // User side
  .rd_clk					(CLIENT_CLK), // input rd_clk
  .dout						(CLIENT_DATA), // output [7 : 0] dout 
  .rd_en					(FIFO_RDEN),//USR_RCV_BEGIN||USER_DATA_VLD), // input rd_en
  
  .full						(), // output full
  .empty					(), // output empty
  .valid					(), // output valid
  .rd_data_count			(RD_DATA_CNT), // output [10 : 0] rd_data_count
  .wr_data_count			() // output [10 : 0] wr_data_count
);

// ������� ������������ ������
always @(posedge EMAC_RXCLK or posedge RST)
    if (RST)        
        begin
            EMAC_DATA <= 8'b0;
            EMAC_VLD  <= 1'b0;
        end
    else if (RX_STOP || RX_RST)
        begin
            EMAC_DATA <= 8'b0;
            EMAC_VLD  <= 1'b0;
        end
    else    
        begin
            EMAC_DATA <= EMAC_RXDATA;
            EMAC_VLD  <= EMAC_RXDATA_VLD; 
        end                   

// ������ �������� ������ ������ �� ���� �� ������� ������������ (Moore FSM)
always @(posedge CLIENT_CLK) 
if (RST)				    												
begin
                                                                FIFO_RST <= 1'b0;
                                                                FIFO_RDEN <= 1'b0;
                                                                CLIENT_DATA_VLD <= 1'b0;
                                                                ST <= IDLE_ST;
end    
else 
(* full_case *)
case (ST)
IDLE_ST:        begin
                                                                FIFO_RST <= 1'b0;
                    if (RX_STOP)                                ST <= IDLE_ST;
                    else 
                        begin                        
				          if (EMAC_RXDATA_VLD)                  ST <= FIFO_WREN_ST;
						  else                                  ST <= IDLE_ST;
						end  
				end	

FIFO_WREN_ST:           if (EMAC_VLD)                           ST <= FIFO_WREN_ST;
                        else                                    
                            begin
                                ST <= FIFO_RDEN_ST;
                                FIFO_RDEN <= 1'b1;
                            end    			
                        							
FIFO_RDEN_ST:		    if ((RD_DATA_CNT <= 'd1)||(RX_RST))		              // ���� ��������� ������ ���������			
                            begin 
                                 FIFO_RDEN <= 1'b0;  
                                 CLIENT_DATA_VLD <= 1'b0;
                                 FIFO_RST      <= 1'b1;
                                if (EMAC_VLD)                   ST <= FIFO_RDEN_ST; 	
                                else                            ST <= IDLE_ST;	
                            end    	    
						else   
							begin            
                                                                ST              <= FIFO_RDEN_ST;	
                                                                FIFO_RDEN       <= 1'b1;
                                                                FIFO_RST        <= 1'b0;
                                                                CLIENT_DATA_VLD <= 1'b1;
                            end 

default:                begin
                                                                ST <= IDLE_ST;
                                                                FIFO_RDEN <= 1'b0;
                                                                CLIENT_DATA_VLD <= 1'b0;
                        end		
endcase

/*
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////// ������� CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [35:0] CONTROL0;
	    
	     chipscope_icon_v1_06_a_0 ICON
	(	.CONTROL0	(CONTROL0)	);
	
	chipscope_ila_v1_05_a_0 ILA
	(
	    .CONTROL	(CONTROL0), // INOUT BUS [35:0]
	    .CLK		(CLIENT_CLK), // IN
	    
	    .TRIG0     	({55'b0,ST,CLIENT_DATA,CLIENT_DATA_VLD}), // IN BUS [63:0]
	    .TRIG1		({52'b0,RX_STOP,FIFO_RST,RX_RST,RD_DATA_CNT,FIFO_RDEN}) // IN BUS [63:0]
	);
*/

endmodule 