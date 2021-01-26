`timescale 1ns/1ps

/*
Декодер принимаемых ICMP сообщений
*/

/*
ICMP_DECODER ICMP_DECODER_inst
(
.RST             	(),
.CLK             	(),     // RX_CLK

.IN_DATA       		(),        //  [7:0]
.IN_DATA_VLD   		(),

// ICMP данные
.ICMP_EN          	(),
.ICMP_HEADER        (), // 68'b0
.ICMP_DATA_REQ		(),		//  I
.ICMP_DONE			()		//  O

.ICMP_DATA		    (),		// [7:0]
.ICMP_DATA_VLD		()		// [7:0]
);
*/
`define ICMP_ECHO_REQ  8'h08        // Запрос ЭХО
`define ICMP_ECHO_REP  8'h00        //  Ответ ЭХО

`define UNSUPPORTED_TYPE_MES 2'b00
`define ECHO_REQ_TYPE        2'b01

module ICMP_DECODER
(
input 					RST,
input 					CLK,     // RX_CLK

input 		[7:0]	 	IN_DATA,
input 					IN_DATA_VLD,
// ICMP данные
input 					ICMP_EN,
output reg  [8*8-1+4:0] ICMP_HEADER,    // из-за поля ICMP_DATA_CHECKSUM размерностью не 16, а 20 бит, размер даного регистра заголовка, который будем транслировать передатчику будет 68 бит и будет отличаться от стандартного 64 бит 
input                  	ICMP_DATA_REQ,
output reg [1:0]        ICMP_TYPE,      // 2'b00 - Принято неправльное сообщение, 2'b01 - Принят ICMP запрос
output reg				ICMP_DONE,

output      [7:0]   	ICMP_DATA,					// Данные в пакете ICMP (у запроса и ответа на этот запрос должен быть одинаковый )
output					ICMP_DATA_VLD
);

localparam ICMP_BYTE0_ST  		= 4'b0001;
localparam ICMP_BYTE1_ST  		= 4'b0011;       
localparam ICMP_BYTE2_ST  		= 4'b0010;       
localparam ICMP_BYTE3_ST		= 4'b0110;
localparam ICMP_BYTE4_ST   		= 4'b0111;     
localparam ICMP_BYTE5_ST		= 4'b0101;
localparam ICMP_BYTE6_ST		= 4'b0100;
localparam ICMP_BYTE7_ST		= 4'b1100;
localparam ICMP_DATA_ST		    = 4'b1101;
localparam ICMP_DONE_ST  		= 4'b1001;       

(* fsm_encoding = "gray" *)
reg [3:0] 		ICMP_ST;
reg [15:0] 		ICMP_IN_CHECKSUM;		// Если не собираемся проверять входной пакет на целостность, то это ненужные нам данные поля о контрольной сумме входного пакета ICMP

reg [7:0]     	ICMP_PROT_TYPE;
reg [7:0]     	ICMP_CODE;
reg [19:0]   	ICMP_DATA_CHECKSUM;     // Контрольная сумма записанных данных из поля данных пакета
reg [15:0]   	ICMP_IDENTIFIER;		// Идентификатор приложения, пославшего запрос (у запроса и ответа на этот запрос должен быть одинаковый )
reg [15:0]   	ICMP_SEQUENCER;			// Порядковый номер запроса, для случая , когда приложение отправило несколько запросов подряд. Чтобы понять на какой запрос пришел ответ (у запроса и ответа на этот запрос должен быть одинаковый )

reg 			FIFO_WREN;
reg 			FIFO_RDEN;
wire [9:0]      RD_DATA_CNT;
wire  		    EMPTY;

always @(posedge CLK or posedge RST)
if (RST)							
begin
ICMP_ST						<= ICMP_BYTE0_ST;
ICMP_HEADER                 <= 68'b0;
ICMP_DONE					<= 0;
ICMP_TYPE                   <= 0;
	
ICMP_PROT_TYPE				<= 0;					
ICMP_CODE					<= 0;						
ICMP_IN_CHECKSUM			<= 0;				 
ICMP_IDENTIFIER				<= 0;			
ICMP_SEQUENCER				<= 0;			
end
else 
(* parallel_case *)(* full_case *)
case (ICMP_ST)
// Прием даных ICMP_TYPE
ICMP_BYTE0_ST:							
                                        begin
                                        ICMP_DONE <= 1'b0;
                                        if (ICMP_EN)	
														begin
															ICMP_ST 					<= ICMP_BYTE1_ST;
															ICMP_PROT_TYPE    			<= IN_DATA;
														end
										else 					
														begin
															ICMP_ST						<= ICMP_BYTE0_ST;
															ICMP_PROT_TYPE    			<= ICMP_PROT_TYPE;
														end
										end				
// Прием даных ICMP_CODE												
ICMP_BYTE1_ST:								begin
															ICMP_ST 					<= ICMP_BYTE2_ST;
															ICMP_CODE    				<= IN_DATA;
											end
// Прием даных ICMP_IN_CHECKSUM													
ICMP_BYTE2_ST:								begin                                                                          													
															ICMP_ST 					<= ICMP_BYTE3_ST;                                                     														
															ICMP_IN_CHECKSUM[15:8]		<= IN_DATA;                                            														
											end  
ICMP_BYTE3_ST:								begin                                                                          
															ICMP_ST						<= ICMP_BYTE4_ST;                                                     
															ICMP_IN_CHECKSUM[7:0]		<= IN_DATA;                                            
											end     
// Прием даных ICMP_IDENTIFIER		
ICMP_BYTE4_ST:								begin                                                                          
															ICMP_ST						<= ICMP_BYTE5_ST;                                                     
															ICMP_IDENTIFIER[15:8]     	<= IN_DATA;                                            
											end      
ICMP_BYTE5_ST:								begin                                                                          
															ICMP_ST 					<= ICMP_BYTE6_ST;                                                     
															ICMP_IDENTIFIER[7:0]       	<= IN_DATA;                                            
											end    
// Прием даных ICMP_SEQUENCER
ICMP_BYTE6_ST:								begin                                                                          
															ICMP_ST 		       		<= ICMP_BYTE7_ST;                                                     													                                                     														
															ICMP_SEQUENCER[15:8]  	    <= IN_DATA;                                         														
											end    
ICMP_BYTE7_ST:                              begin							
															ICMP_ST 					<= ICMP_DATA_ST;
															ICMP_SEQUENCER[7:0]         <= IN_DATA;                                           			
											end			
// Прием даных из поля данных ICMP	
ICMP_DATA_ST:		if ((ICMP_PROT_TYPE == 8'd8)&&(ICMP_CODE == 8'd0))
                        begin
                            if (IN_DATA_VLD)   ICMP_ST	<= ICMP_DATA_ST;
							else               ICMP_ST	<= ICMP_DONE_ST;	
						end				
					else 
						begin
						    ICMP_DONE       <= 1'b1;
						    ICMP_TYPE       <= `UNSUPPORTED_TYPE_MES;
						    ICMP_ST         <= ICMP_DONE_ST;
						end    					
ICMP_DONE_ST:       begin				    
                        ICMP_DONE                   <= 0;
                        if (IN_DATA_VLD)		    
                            begin
                                ICMP_ST      <= ICMP_DONE_ST;
                                //ICMP_HEADER  <= 68'b0;          // Валидность данных на входе присутствует в случае, когда в предыдущем состоянии мы определили, что мы приняли не ICMP-запрос
                            end     
						else
						  begin
						        ICMP_DONE    <= 1'b1;
						        ICMP_TYPE    <= `ECHO_REQ_TYPE;
							    ICMP_ST      <= ICMP_BYTE0_ST;
						        ICMP_HEADER  <= {ICMP_SEQUENCER,ICMP_IDENTIFIER,ICMP_DATA_CHECKSUM,ICMP_CODE,ICMP_PROT_TYPE};  // Если приняли ICMP-запрос. Записываем контрольную сумму принятых данных, а не контрольную сумму входного пакета
						  end	     
					end    
default:
    				begin
    					ICMP_ST 					<= ICMP_BYTE0_ST;
    					ICMP_DONE					<= 0;	
    	                ICMP_HEADER                 <= ICMP_HEADER;
     	               
    					ICMP_PROT_TYPE				<= 0;					
    					ICMP_CODE					<= 0;						
    	       			ICMP_IN_CHECKSUM			<= 0;				 
    			     	ICMP_IDENTIFIER				<= 0;			
    					ICMP_SEQUENCER				<= 0;			
    				end
endcase												

fifo_icmp fifo_icmp_inst
 (
  .rst             	(RST),	 		// input rst
  
  .wr_clk        	(CLK),					// input wr_clk
  .wr_en          	(FIFO_WREN), 	// input wr_en
  .din             	(IN_DATA), 	// input [7 : 0] din
  
  .rd_clk          	(CLK),			 // input rd_clk
  .rd_en          	(FIFO_RDEN), 		// input rd_en
  .dout           	(ICMP_DATA), 	// output [7 : 0] dout
  .wr_data_count    (), 						// output [9 : 0] wr_data_count

  .full            	(), 						// output full
  .empty         	(EMPTY), 	// Empty if RD_DATA_CNT == 0
  .valid           	(), 						// output valid
  .rd_data_count    (RD_DATA_CNT)          // output [9 : 0] rd_data_count
);

// Управление FIFO
//assign FIFO_WREN   					= ((ICMP_ST == ICMP_DATA_ST)&&(IN_DATA_VLD))?1'b1:1'b0;

always @(*)
if ((ICMP_ST == ICMP_DATA_ST)&&(IN_DATA_VLD))  FIFO_WREN <= 1'b1;
else                                           FIFO_WREN <= 1'b0; 

always @(posedge CLK or posedge RST)
if (RST)                       									FIFO_RDEN <= 1'b0;
else if (ICMP_DATA_REQ)         								FIFO_RDEN <= 1'b1;
else if (RD_DATA_CNT <= 10'b0)              			        FIFO_RDEN <= 1'b0;
else                  											FIFO_RDEN <= FIFO_RDEN;

assign ICMP_DATA_VLD = FIFO_RDEN;

////////////////////////////
// Подсчет контрольной суммы

/* Для расчета контрольной суммы надо использовать только двухбайтные значения
        Тогда укладываем входные однобайтные отсчеты в двухбайтное слово и считаем контрольную сумму 
*/

reg CHECKSUM_CNT;
wire [15:0] DATA_16;

always @(posedge CLK or posedge RST)
if (RST)                CHECKSUM_CNT <= 0;
else if (FIFO_WREN)     CHECKSUM_CNT <= CHECKSUM_CNT + 1'b1;   
else                    CHECKSUM_CNT <= 0;

assign DATA_16[15:8] = (FIFO_WREN&&CHECKSUM_CNT)   ? DATA_16[15:8]:IN_DATA;
assign DATA_16[7:0] =  (FIFO_WREN&&(!CHECKSUM_CNT))? DATA_16[7:0]:IN_DATA;

always @(posedge CLK)
if (RST)			    ICMP_DATA_CHECKSUM <= 0;
else if (CHECKSUM_CNT)	ICMP_DATA_CHECKSUM <= ICMP_DATA_CHECKSUM + {4'b0,DATA_16};
else if (ICMP_DONE)     ICMP_DATA_CHECKSUM <= 0;
else                    ICMP_DATA_CHECKSUM <= ICMP_DATA_CHECKSUM;
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
	    
	    .TRIG0			({37'b0,RD_DATA_CNT,EMPTY,FIFO_WREN,FIFO_RDEN,ICMP_DATA,ICMP_DATA_VLD,ICMP_DATA_REQ,ICMP_ST,IN_DATA,IN_DATA_VLD,ICMP_DONE,ICMP_EN}), // IN BUS [63:0]
	    .TRIG1			(ICMP_HEADER[63:0]) // IN BUS [63:0]
	);
*/	

endmodule