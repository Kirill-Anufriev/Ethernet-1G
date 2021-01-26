`timescale 1ns / 1ps

/*
CLIENT_MAC_RX CLIENT_MAC_RX
(
.RST                    (),
// FROM EMAC
.EMAC_RXDATA            (),   //  [7:0] ѕринимаемые данные от MAC €дра
.EMAC_RXDATA_VLD        (),   //  ¬алидность принимаемых данных 
.EMAC_RXCLK             (),	  //  “актова€ частота принимаемых данных от MAC €дра 
.EMAC_RXSTATS           (),   // [6:0] —татистика по последним прин€тым даным. 28 битный вектор передаетс€ последовательно по 7 бит за такт  
.EMAC_RXSTATSVLD        (),   // ¬алидность статистических данных приемника
.EMAC_RXSTATSBYTEVLD    (),	
// FROM CLIENT
.CLIENT_CLK             (),
.CLIENT_DATA            (),
.CLIENT_DATA_VLD        (),
.RX_STOP                (),   // ѕриостанавливаем прием сообщений дл€ того чтобы правильно передать имеющиес€ данные
.RX_RST                 ()    // ≈сли декодеры сообщили, что принимаемое сообщение нам не подходит
);
*/

//ћодуль приема данных от €дра EMAC может принимать до 2048 байт данных единовеременно. –азмер FIFO 2048 х 8 

module CLIENT_MAC_RX
(
input       RST,
// FROM EMAC
input [7:0] EMAC_RXDATA,   	   //  [7:0] ѕринимаемые данные от MAC €дра
input 		EMAC_RXDATA_VLD,   //  ¬алидность принимаемых данных 
input 		EMAC_RXCLK,		   //  “актова€ частота принимаемых данных от MAC €дра 
input [6:0] EMAC_RXSTATS,      // [6:0] —татистика по последним прин€тым даным. 28 битный вектор передаетс€ последовательно по 7 бит за такт  
input       EMAC_RXSTATSVLD,   // ¬алидность статистических данных приемника
input       EMAC_RXSTATSBYTEVLD,	
// FROM CLIENT
input 		CLIENT_CLK,
output[7:0]	CLIENT_DATA,
output reg	CLIENT_DATA_VLD,
input       RX_STOP,                // ѕриостанавливаем прием сообщений дл€ того чтобы правильно передать имеющиес€ данные
input       RX_RST                  // ≈сли декодеры сообщили, что принимаемое сообщение нам не подходит
);

//localparam IDLE_ST 	        = 2'b001;
//localparam FIFO_WREN_ST 	= 2'b011;
//localparam FIFO_RDEN_ST 	= 2'b010;

parameter [1:0]     IDLE_ST      =   2'b01,
                    FIFO_WREN_ST =   2'b11,
                    FIFO_RDEN_ST =   2'b10;

(*fsm_encoding = "gray"*)
reg [1:0] 		ST;			// —осто€ни€ , когда пользователь читает данные из фифо
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

// ¬ходное защелкивание данных
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

// ћашина состоний чтени€ данных из фифо на частоте пользовател€ (Moore FSM)
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
                        							
FIFO_RDEN_ST:		    if ((RD_DATA_CNT <= 'd1)||(RX_RST))		              // ≈сли полностью прочли сообщение			
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
///////////////////////////////////////////////////////////////////////////////////////////////// ќтладка CHIP SCOPE ///////////////////////////////////////////////////////////////////////////////////////////////////////
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