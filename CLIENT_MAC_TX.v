`timescale 1ns / 1ps

/*
CLIENT_MAC_TX CLIENT_MAC_TX
(
.RST                (),
// CLIENT SIDE
.CLIENT_CLK         (),
.CLIENT_DATA        (),    // [7:0]
.CLIENT_DATA_VLD    (),
// EMAC CORE SIDE
.EMAC_TXD           (),	   //  [7:0] Данные для передачи
.EMAC_TXDVLD        (),    //  Валидность данных на входе
.EMAC_CLK           (),	   //  Тактовая частота данных в MAC ядро
.EMAC_TXACK         (),    //  Сигнал согласования. Оповещает, что ядро приняло первый байт данных
.EMAC_TXSTATS       (),    //  Статистика по последним переданным данным. 32-х битный вектор передается последовательно по биту за такт 
.EMAC_TXSTATSVLD    (),    //  Валидность статистических данных передатчика
.EMAC_TXSTATSBYTEVLD(),	   //  Сигнал подтверждения передачи каждого байта кадра, включая адрес назначения FCS. Активен в каждый период передачи 
.EMAC_TXCOLLISION   (),    //  Сигнал о том, что на линии происходит коллизия. Все передачи должны прекратиться. Не применяется в полнодуплексном режиме
.EMAC_TXRETRANSMIT  ()     //  НЕ ИСПОЛЬЗУЕМ. Выставляется совместно с сигналом коллизии. Клиент обязан заново начать передачу текущего кадра. Не применяется в полнодуплексном режиме
);
*/

module CLIENT_MAC_TX
(
input 			RST,
// CLIENT SIDE
input 			CLIENT_CLK,
input [7:0] 	CLIENT_DATA,
input 		   	CLIENT_DATA_VLD,
output reg      CLIENT_TX_STOP,             // Чтобы случайно не возникло коллизии, на время передачи данных из буфера в сеть перекрываем канал передачи данных от пользователя в буфер
// EMAC CORE SIDE
 output    [7:0]EMAC_TXD,            		//  [7:0] Данные для передачи
 output	reg		EMAC_TXDVLD,         		//  Валидность данных на входе
 input	 		EMAC_CLK,					//  Тактовая частота данных в MAC ядро
 input 			EMAC_TXACK,          		//  Сигнал согласования. Оповещает, что ядро приняло первый байт данных
 input 			EMAC_TXSTATS,      			//  Статистика по последним переданным данным. 32-х битный вектор передается последовательно по биту за такт 
 input 			EMAC_TXSTATSVLD,   			//  Валидность статистических данных передатчика
 input 			EMAC_TXSTATSBYTEVLD,		//  Сигнал подтверждения передачи каждого байта кадра, включая адрес назначения FCS. Активен в каждый период передачи 
 input 			EMAC_TXCOLLISION,    		//  Сигнал о том, что на линии происходит коллизия. Все передачи должны прекратиться. Не применяется в полнодуплексном режиме
 input 			EMAC_TXRETRANSMIT  			//  НЕ ИСПОЛЬЗУЕМ. Выставляется совместно с сигналом коллизии. Клиент обязан заново начать передачу текущего кадра. Не применяется в полнодуплексном режиме
);
   
    parameter [3:0]     WR_IDLE_ST 	  = 3'b001,
                        RAM_WREN_ST   = 3'b011,
                        WAIT_RD_ST    = 3'b010,
    
                        INIT_READ_ST  = 3'b110,
                        WAIT_ACK_ST   = 3'b111,
                        RAM_RDEN_ST   = 3'b101,
                        RD_DONE_ST    = 3'b100;
    
(*fsm_encoding = "gray"*)
    reg  [2:0]  WR_ST;			// Состояния , когда MAC пишет данные в память
    reg         WR_DONE;
    reg  [2:0]  RD_ST;			// Состояния , когда данные из RAM вычитываются
    reg         RD_DONE;
    reg  [10:0] ADDR_A;
    reg  [10:0] ADDR_B;
    wire [7:0]  RAM_O_DATA;
    reg  [7:0]  RAM_O_DATA_init;
    
    reg [5:0]  STAT_CNT;
    reg [31:0] STAT_DATA;
    
   TX_RX_RAM_2k OUTPUT_RAM_BUFFER 
   (
      .rstb     (RST),              // input rstb
      
      .clka     (CLIENT_CLK),       // input clka
      .wea      (CLIENT_DATA_VLD),  // input [0 : 0] wea
      .addra    (ADDR_A),           // input [10 : 0] addra
      .dina     (CLIENT_DATA),      // input [7 : 0] dina
            
      .clkb     (EMAC_CLK),     // input clkb
      .addrb    (ADDR_B),           // input [10 : 0] addrb
      .doutb    (RAM_O_DATA) // output [7 : 0] doutb
    );
    
 // Машина состоний записи данных в RAM блок для передачи
always @(posedge CLIENT_CLK or posedge RST) 
if (RST)
    begin
	     WR_ST             <= WR_IDLE_ST;
	     WR_DONE           <= 1'b0;
	     ADDR_A            <= 0;
	     CLIENT_TX_STOP    <= 1'b0;
	end     
else 
(* full_case *)
case(WR_ST)
WR_IDLE_ST:    begin
                if (CLIENT_DATA_VLD)  
                    begin
                        ADDR_A  <= 11'b1;
                        WR_ST   <= RAM_WREN_ST;
                    end
                else    
                    begin
                        WR_ST <= WR_IDLE_ST;
                        ADDR_A    <= 11'b0;
                    end    
            end
                    
RAM_WREN_ST:  if (CLIENT_DATA_VLD)  
                begin
                    ADDR_A <= ADDR_A + 1'b1;        
                    WR_ST <= RAM_WREN_ST;
                end    
              else 
                begin  
                    WR_ST            <= WAIT_RD_ST;  
                    ADDR_A           <= ADDR_A; 
                end   
                
WAIT_RD_ST:   begin
                if (RD_DONE)    
                    begin
                        WR_ST           <= WR_IDLE_ST;
                        WR_DONE         <= 1'b0;
                        CLIENT_TX_STOP  <= 1'b0;
                    end    
                else 
                   begin
                        WR_ST           <= WAIT_RD_ST;
                        CLIENT_TX_STOP  <= 1'b1;
                        WR_DONE         <= 1'b1;
                   end
              end             
default:
        begin
            WR_ST             <= WR_IDLE_ST;
            WR_DONE           <= 1'b0;
            CLIENT_TX_STOP    <= 1'b0;
            ADDR_A            <= 0;
        end                
endcase                        



always @(posedge EMAC_CLK or posedge RST) 
if (RST)
    begin
	     RD_ST             <= INIT_READ_ST;
	     RD_DONE           <= 1'b0;
	     EMAC_TXDVLD  <= 1'b0;
	     ADDR_B            <= 11'b0;
	     RAM_O_DATA_init   <= 8'b0;
	end     
else 
(* full_case *)
case(RD_ST)
INIT_READ_ST: if (WR_DONE)
                 begin
                        if (EMAC_TXCOLLISION)
                            begin
                                RD_ST               <= INIT_READ_ST;
                                EMAC_TXDVLD         <= 1'b0;
                                RAM_O_DATA_init     <= 8'b0;
                            end        
                        else                             
                            begin
                                RD_ST               <= WAIT_ACK_ST;
                                ADDR_B              <= 11'b0;
                                RAM_O_DATA_init     <= RAM_O_DATA;
                            end    
                 end
              else
                 begin
                    ADDR_B              <= 11'b0;
                    RD_ST               <= INIT_READ_ST;
                    EMAC_TXDVLD         <= 1'b0;
                    RAM_O_DATA_init     <= 8'b0;
                 end   

WAIT_ACK_ST:  if (EMAC_TXCOLLISION)
                begin
                    RD_ST            <= INIT_READ_ST;
                    ADDR_B           <= 11'd0;
                    EMAC_TXDVLD      <= 1'b0;
                end
              else    
                begin  
                        EMAC_TXDVLD    <= 1'b1; 
                       if (EMAC_TXACK)
                        begin
                            ADDR_B          <= ADDR_B + 1'b1;
                            RD_ST           <= RAM_RDEN_ST;
                        end    
                       else   
                        begin
                            RD_ST               <= WAIT_ACK_ST;
                            ADDR_B              <= 11'd1;
                            RAM_O_DATA_init     <= RAM_O_DATA_init;
                        end     
                end            
                            
RAM_RDEN_ST:    if (EMAC_TXCOLLISION)
                    begin
                        RD_ST            <= INIT_READ_ST;
                        EMAC_TXDVLD <= 0;
                    end
                else    
                    begin
                        if (ADDR_B >= ADDR_A - 1'b1)
                            begin                            
                                RD_ST            <= RD_DONE_ST;
                            end
                        else 
                            begin
                                RD_ST           <= RAM_RDEN_ST;
                                ADDR_B          <= ADDR_B + 1'b1;
                            end 
                    end
                    
RD_DONE_ST: begin
                EMAC_TXDVLD <= 1'b0;
                if (!WR_DONE)
                    begin
                        ADDR_B <=  11'b0;
                        RD_ST   <= INIT_READ_ST;
                        RD_DONE <= 1'b0;
                    end
                else 
                    begin
                        RD_ST   <= RD_DONE_ST;
                        RD_DONE <= 1'b1;
                    end
            end

default:   begin
            RD_ST             <= INIT_READ_ST;
            RD_DONE           <= 1'b0;
            EMAC_TXDVLD  <= 1'b0;
            ADDR_B            <= 0; 
            RAM_O_DATA_init   <= 8'b0;
           end
                   
endcase 

assign EMAC_TXD = (RD_ST == WAIT_ACK_ST)?RAM_O_DATA_init:RAM_O_DATA;

/****************************************************/
/************* Прием данных статуса *****************/
/****************************************************/

always @(posedge EMAC_CLK or posedge RST)
if (RST)                        STAT_CNT <= 0;
else if (EMAC_TXSTATSVLD)
    begin
        if (STAT_CNT >= 6'd31)  STAT_CNT <= STAT_CNT;
        else                    STAT_CNT <= STAT_CNT + 1'b1;
    end
else                            STAT_CNT <= 0;                

always @(posedge EMAC_CLK or posedge RST)
if (RST)                        STAT_DATA           <= 0;
else if (STAT_CNT >= 6'd31)     STAT_DATA           <= STAT_DATA;
else                            STAT_DATA [STAT_CNT]<= EMAC_TXSTATS;

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
	    .CLK			(CLIENTMACCLK), // IN
	    
	    .TRIG0			({15'b0,CLIENTEMACTXDVLD,CLIENTEMACTXD,STAT_DATA,STAT_CNT,EMACCLIENTTXSTATS,USER_DATA_VLD}), // IN BUS [63:0]
	    .TRIG1			({15'b0,RAM_O_DATA,RAM_O_DATA_init,ADDR_B,ADDR_A,EMACCLIENTTXACK,EMACCLIENTTXSTATSVLD,USER_DATA,EMACCLIENTTXCOLLISION}) // IN BUS [63:0]
	);
*/     
endmodule
