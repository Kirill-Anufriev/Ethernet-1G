`timescale 1ns / 1ps

/*
DATA_CHANGING_CONTROLLER DATA_CHANGING_CONTROLLER_inst
(
.CLK                    (),
.RST                    (),

.IN_REQ_TYPE_VLD        (), //
.IN_REQ_TYPE            (), // Тип входного запроса. 

.IN_MAC_HEADER          (), // [14*8-1:0]  
.IN_ARP_HEADER          (), // [28*8-1:0]
.IN_IP_HEADER           (), // [20*8-1:0]
.IN_ICMP_HEADER         (), // [8*8+4-1:0]
.IN_UDP_HEADER          (), // [8*8-1:0]
//.TCP_HEADER           (), //

.OUT_REQ_TYPE           (), // Тип выходного запроса
.OUT_REQ_TYPE_VLD       (), //               
.REQ_DONE               (), // Обработка запроса завершена

.OUT_MAC_HEADER         (), // [14*8-1:0]  
.OUT_ARP_RARP_HEADER    (), // [28*8-1:0]  
.OUT_IP_HEADER          (), // [20*8-1:0]  
.OUT_ICMP_HEADER        (), // [8*8+4-1:0] 
.OUT_UDP_HEADER         ()  // [8*8-1:0]    
//.TCP_HEADER           ()  //
);
*/

/*
Контроллер обмена данными Ethernet. Выполняет функции буфера заголовков и арбитра
Приоритер протоколов такой:
1) ARP, RARP,
2) UDP, TCP,
3) ICMP,

С запросом ARP нужно запоминать полностью заголовок MAC + ARP
С запросом RARP нужно запоминать полностью заголовок MAC + RARP
С запросом ICMP нужно запоминать полностью заголовок MAC + IP + ICMP
С запросом UDP нужно запоминать полностью заголовок MAC + IP + UDP 

Модуль осуществляет арбитраж комманд для передачи данных. В момент команлы на передачу модуль предоставляет импульс активации передачи, 
    а так же все необходимые заголовочные данные приемной и передающей стороны. Удостоверивишись в завершении передачи, модуль переходит к другой задаче.
*/

/*Код типа принятого сообщения или запроса*/
`define UNSUPPORTED_TYPE_MES    4'bxx00
`define ARP_TYPE_MES            4'b0101
`define RARP_TYPE_MES           4'b1001
`define ICMP_TYPE_MES           4'b0110
`define UDP_TYPE_MES            4'b1010
`define TCP_TYPE_MES            4'b1110
/*****************************************/

module DATA_CHANGING_CONTROLLER
(
input  CLK,
input  RST,

input       IN_MESS_TYPE_VLD,
input [3:0] IN_MESS_TYPE,               // Тип входного запроса. [1:0] - тип протокола сетевого уровня, [3:2] - тип протокола транспортного уровня
                                        // IN_MESS_TYPE [1:0] 2'b00 - необрабатываемый далее тип запроса, 2'b01 - ARP запрос, 2'b10 - IP запрос. 
                                            // IN_MESS_TYPE [3:2] для ARP запроса 2'b00 - ARP  , 2'b01 - RARP,
                                            // IN_MESS_TYPE [3:2] для IP  запроса 2'b00 - ICMP , 2'b01 - UDP, 2'b10 - TCP
                                        
input       USER_DATA_TRANSFER_REQ,     //Если пришел запрос от формирователя данных на передачу данных
 
input [14*8-1:0] IN_MAC_HEADER,         // Заголовок MAC 14 байт
input [28*8-1:0] IN_ARP_HEADER,
input [20*8-1:0] IN_IP_HEADER,
input [8*8+4-1:0]IN_ICMP_HEADER,
input [8*8-1:0]  IN_UDP_HEADER,
//input [20*8-1:0] TCP_HEADER,

input            OUT_BUF_STATE,     // Состояние выходного буффера передачи данных
output reg [3:0] OUT_REQ_TYPE,          
output reg       OUT_REQ_TYPE_VLD,  
input            REQ_DONE,    

output reg [14*8-1:0] OUT_MAC_HEADER,         
output reg [28*8-1:0] OUT_ARP_HEADER,
output reg [20*8-1:0] OUT_IP_HEADER,
output reg [8*8+4-1:0]OUT_ICMP_HEADER,
output reg [8*8-1:0]  OUT_UDP_HEADER
//output reg [20*8-1:0] TCP_HEADER,
);

localparam IDLE_ST = 2'b01,
           DONE_ST = 2'b10;     

// Поскольку в процессе работы передатчика к нам могут прийти новые запросы, то, чтобы случайно ошибочно не поменять поля заголовком в ходе отправки сообщения
//  заголовки будем выдавать для формирования только в момент формирования запроса на отправку OUT_REQ_TYPE. 
//  Буфер ниже расчитан лишь на хранение последних принятых данных одного запроса каждого типа. Соответствено и отвечать будем только на один последний запрос каждого типа
reg [3:0]      REQ_STACK; // Стопка запросов. 4'bxxx1 - ARP, 4'bxx1x - RARP, 4'bx1xx - UDP, 4'b1xxx - ICMP

reg [1:0]      ST;

reg [3:0]      IN_MESS_TYPE_reg; 

//Для каждого типа сообщения свои данные заголовков
reg [14*8-1:0] IN_MAC_ARP_RARP_HEADER_reg;      
reg [28*8-1:0] IN_ARP_RARP_HEADER_reg;

reg [14*8-1:0] IN_MAC_ICMP_HEADER_reg;   
reg [20*8-1:0] IN_IP_ICMP_HEADER_reg;
reg [8*8-1:0]  IN_ICMP_HEADER_reg;

reg [14*8-1:0] IN_MAC_UDP_HEADER_reg;
reg [20*8-1:0] IN_IP_UDP_HEADER_reg;
reg [8*8-1:0]  IN_UDP_HEADER_reg;

reg [10:0]     OVERTIME_CNT;        // Счетчик превышения максимального времени ожидания исполнения запроса  
reg            OVERTIME_EN;         // Время на обработку запроса вышло
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/************ Для каждого из возможных типов сообщений запоминаем заголовки, которые приняли вместе с сообщением ******************/
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
always @(posedge CLK or posedge RST)
if (RST) 
    begin
        IN_MAC_ARP_RARP_HEADER_reg  <= 'd0;      
        IN_ARP_RARP_HEADER_reg      <= 'd0;
        
        IN_MAC_ICMP_HEADER_reg      <= 'd0;  
        IN_IP_ICMP_HEADER_reg       <= 'd0;
        IN_ICMP_HEADER_reg          <= 'd0;
        
        IN_MAC_UDP_HEADER_reg       <= 'd0;
        IN_IP_UDP_HEADER_reg        <= 'd0;
        IN_UDP_HEADER_reg           <= 'd0;
    end
else if (IN_MESS_TYPE_VLD)
    begin
    case (IN_MESS_TYPE[1:0])
        2'b00:          // Необрабатываемые запросы
            begin
                IN_MAC_ARP_RARP_HEADER_reg  <= IN_MAC_ARP_RARP_HEADER_reg;      
                IN_ARP_RARP_HEADER_reg      <= IN_ARP_RARP_HEADER_reg;
            
                IN_MAC_ICMP_HEADER_reg      <= IN_MAC_ICMP_HEADER_reg;  
                IN_IP_ICMP_HEADER_reg       <= IN_IP_ICMP_HEADER_reg;
                IN_ICMP_HEADER_reg          <= IN_ICMP_HEADER_reg;
            
                IN_MAC_UDP_HEADER_reg       <= IN_MAC_UDP_HEADER_reg;
                IN_IP_UDP_HEADER_reg        <= IN_IP_UDP_HEADER_reg;
                IN_UDP_HEADER_reg           <= IN_UDP_HEADER_reg;
            end
        2'b01:          // ARP
            begin
                case (IN_MESS_TYPE[3:2])
                    2'b01:      //ARP
                        begin
                            IN_MAC_ARP_RARP_HEADER_reg  <= IN_MAC_HEADER; 
                            IN_ARP_RARP_HEADER_reg      <= IN_ARP_HEADER;
                        end    
                    2'b10:      //RARP
                        begin
                            IN_MAC_ARP_RARP_HEADER_reg  <= IN_MAC_HEADER; 
                            IN_ARP_RARP_HEADER_reg      <= IN_ARP_HEADER;
                        end              
                    default:
                        begin
                            IN_MAC_ARP_RARP_HEADER_reg  <= IN_MAC_ARP_RARP_HEADER_reg; 
                            IN_ARP_RARP_HEADER_reg      <= IN_ARP_RARP_HEADER_reg;
                        end    
                endcase
            end
        2'b10:          // IP
                case (IN_MESS_TYPE[3:2])
                    2'b01:      // ICMP
                        begin
                            IN_MAC_ICMP_HEADER_reg      <= IN_MAC_HEADER;  
                            IN_IP_ICMP_HEADER_reg       <= IN_IP_HEADER;
                            IN_ICMP_HEADER_reg          <= IN_ICMP_HEADER;
                        end
                    2'b10:      // UDP
                        begin
                            IN_MAC_UDP_HEADER_reg       <= IN_MAC_HEADER;
                            IN_IP_UDP_HEADER_reg        <= IN_IP_HEADER;
                            IN_UDP_HEADER_reg           <= IN_UDP_HEADER;
                        end   
                    //2'b11:      // TCP
                    //    begin
                    //    end
                    default:
                        begin
                            IN_MAC_ICMP_HEADER_reg      <= IN_MAC_ICMP_HEADER_reg ;  
                            IN_IP_ICMP_HEADER_reg       <= IN_IP_ICMP_HEADER_reg;
                            IN_ICMP_HEADER_reg          <= IN_ICMP_HEADER_reg;
                        
                            IN_MAC_UDP_HEADER_reg       <= IN_MAC_UDP_HEADER_reg;
                            IN_IP_UDP_HEADER_reg        <= IN_IP_UDP_HEADER_reg;
                            IN_UDP_HEADER_reg           <= IN_UDP_HEADER_reg;
                        end
                  endcase
        default:
            begin
                IN_MAC_ARP_RARP_HEADER_reg  <= IN_MAC_ARP_RARP_HEADER_reg; 
                IN_ARP_RARP_HEADER_reg      <= IN_ARP_RARP_HEADER_reg;
                
                IN_MAC_ICMP_HEADER_reg      <= IN_MAC_ICMP_HEADER_reg ;  
                IN_IP_ICMP_HEADER_reg       <= IN_IP_ICMP_HEADER_reg;
                IN_ICMP_HEADER_reg          <= IN_ICMP_HEADER_reg;
        
                IN_MAC_UDP_HEADER_reg       <= IN_MAC_UDP_HEADER_reg;
                IN_IP_UDP_HEADER_reg        <= IN_IP_UDP_HEADER_reg;
                IN_UDP_HEADER_reg           <= IN_UDP_HEADER_reg;
            end
     endcase       
    end
/*******************************************************************/
/***************** Формирование очереди задач **********************/
/*******************************************************************/
    always @(posedge CLK or posedge RST)
    if (RST) 
        begin
            IN_MESS_TYPE_reg            <= 'd0; 
            REQ_STACK                   <= 4'b0000;
        end
    else if (REQ_DONE || OVERTIME_EN)              // Если пришло сообщение о том, что запрос обработан, то смотрим что за запрос и убираем его из очереди
        case (OUT_REQ_TYPE)
                `ARP_TYPE_MES:  REQ_STACK[0]       <= 1'b0;      // ARP
                `RARP_TYPE_MES: REQ_STACK[1]       <= 1'b0;      // RARP
                `UDP_TYPE_MES:  REQ_STACK[2]       <= 1'b0;      // UDP
                `ICMP_TYPE_MES: REQ_STACK[3]       <= 1'b0;      // ICMP
                default:  REQ_STACK                <= 0;
        endcase
    else        
        begin    // Если приняли новый запрос - помещаем его в очередь
               if ((IN_MESS_TYPE_VLD)&&(IN_MESS_TYPE == `ARP_TYPE_MES))   REQ_STACK[0] <= 1'b1; // ARP   
          else if ((IN_MESS_TYPE_VLD)&&(IN_MESS_TYPE == `RARP_TYPE_MES))  REQ_STACK[1] <= 1'b1; // RARP  
          else if (USER_DATA_TRANSFER_REQ)                                REQ_STACK[2] <= 1'b1; // Если пришел запрос на отправку данных   
          else if ((IN_MESS_TYPE_VLD)&&(IN_MESS_TYPE == `ICMP_TYPE_MES))  REQ_STACK[3] <= 1'b1; // RARP
          else                                                            REQ_STACK    <= REQ_STACK;                          
        end

/**********************************************************************/
/**************** Арбитр активной задачи ******************************/
/**********************************************************************/
/*
Приоритет задач:
На первом месте ARP И RARP запросы, потому что если ARP запросчик не получит ответ, то он не будет воспринимать любые другие сообщения
На втором месте пакеты данных UDP и TCP
На третьем месте ICMP, потому что информация пинг нам нужна только для того, чтобы знать на связи-ли наша плата
*/

always @(posedge CLK or posedge RST)
if (RST)
    begin
        ST                  <= IDLE_ST;
        
        OUT_REQ_TYPE        <= 4'd0;
        OUT_REQ_TYPE_VLD    <= 1'b0;
        
        OUT_MAC_HEADER      <= 'd0;
        OUT_ARP_HEADER      <= 'd0;
        OUT_IP_HEADER       <= 'd0;
        OUT_ICMP_HEADER     <= 'd0;
        OUT_UDP_HEADER      <= 'd0;
        
        OVERTIME_CNT        <= 11'b0;       // Счетчик ожидания обработки запроса. Если запрос не обработан за отведенное время, то считаем его завершенным и выполняем другой запрос
        OVERTIME_EN         <= 1'b0;
    end
else case(ST)
IDLE_ST:    
        begin
        OVERTIME_EN         <= 1'b0;    
        if (OUT_BUF_STATE == 1'b0)    // Если выходной буфер не занят
            begin
                casex (REQ_STACK)
                    4'b0000:
                        begin
                            ST                  <= IDLE_ST;
                                        
                            OUT_REQ_TYPE        <= 4'b0000;
                            OUT_REQ_TYPE_VLD    <= 1'b0;
                            OUT_MAC_HEADER      <= 'd0;
                            OUT_ARP_HEADER      <= 'd0;
                            OUT_IP_HEADER       <= 'd0;
                            OUT_ICMP_HEADER     <= 'd0;
                            OUT_UDP_HEADER      <= 'd0;
                        end
  
  /*ARP*/           4'bxxx1:
                        begin
                            ST                  <= DONE_ST;
                         
                            OUT_REQ_TYPE        <= `ARP_TYPE_MES;
                            OUT_REQ_TYPE_VLD    <= 1'b1;
                            OUT_MAC_HEADER      <= IN_MAC_ARP_RARP_HEADER_reg;
                            OUT_ARP_HEADER      <= IN_ARP_RARP_HEADER_reg;
                        end    
  /*RARP*/          4'bxx10:
                        begin
                            ST                  <= DONE_ST;
                     
                            OUT_REQ_TYPE        <= `RARP_TYPE_MES;
                            OUT_REQ_TYPE_VLD    <= 1'b1;
                            OUT_MAC_HEADER      <= IN_MAC_ARP_RARP_HEADER_reg;
                            OUT_ARP_HEADER      <= IN_ARP_RARP_HEADER_reg;
                        end
  /*UDP*/           4'bx100:
                        begin
                           ST                  <= DONE_ST;
                                       
                           OUT_REQ_TYPE        <= `UDP_TYPE_MES;
                           OUT_REQ_TYPE_VLD    <= 1'b1;
                           
                           OUT_MAC_HEADER      <= IN_MAC_UDP_HEADER_reg;
                           OUT_IP_HEADER       <= IN_IP_UDP_HEADER_reg;
                           OUT_UDP_HEADER      <= IN_UDP_HEADER_reg;
                        end
  /*ICMP*/          4'b1000:
                        begin
                           ST                  <= DONE_ST;
                                         
                           OUT_REQ_TYPE        <= `ICMP_TYPE_MES;
                           OUT_REQ_TYPE_VLD    <= 1'b1;
                             
                           OUT_MAC_HEADER      <= IN_MAC_ICMP_HEADER_reg;
                           OUT_IP_HEADER       <= IN_IP_ICMP_HEADER_reg;
                           OUT_ICMP_HEADER     <= IN_ICMP_HEADER_reg;
                         end
                endcase
            end
        else 
            begin
                    ST                  <= IDLE_ST;
                                
                    OUT_REQ_TYPE        <= 4'b0000;
                    OUT_REQ_TYPE_VLD    <= 1'b0;
                    OUT_MAC_HEADER      <= OUT_MAC_HEADER;
                    OUT_ARP_HEADER      <= OUT_ARP_HEADER;
                    OUT_IP_HEADER       <= OUT_IP_HEADER;
                    OUT_ICMP_HEADER     <= OUT_ICMP_HEADER;
                    OUT_UDP_HEADER      <= OUT_UDP_HEADER;
            end
        end    
DONE_ST:    if  (OVERTIME_CNT <= 11'd2000)
                begin
                    if (REQ_DONE)
                        begin
                            ST                  <= IDLE_ST;
             
                            OUT_REQ_TYPE        <= 'd0;
                            OUT_REQ_TYPE_VLD    <= 1'b0;
                            OUT_MAC_HEADER      <= 'd0;
                            OUT_ARP_HEADER      <= 'd0;
                            OUT_IP_HEADER       <= 'd0;
                            OUT_ICMP_HEADER     <= 'd0;
                            OUT_UDP_HEADER      <= 'd0;
                            
                            OVERTIME_CNT        <= 11'd0;
                        end    
                    else    
                        begin
                            ST                  <= DONE_ST;
                 
                            OUT_REQ_TYPE        <= OUT_REQ_TYPE;
                            OUT_REQ_TYPE_VLD    <= 1'b0;
                            OUT_MAC_HEADER      <= OUT_MAC_HEADER;
                            OUT_ARP_HEADER      <= OUT_ARP_HEADER;
                            OUT_IP_HEADER       <= OUT_IP_HEADER;
                            OUT_ICMP_HEADER     <= OUT_ICMP_HEADER;
                            OUT_UDP_HEADER      <= OUT_UDP_HEADER;
                            
                            OVERTIME_CNT        <= OVERTIME_CNT + 1'b1;
                        end
                end        
             else
                begin
                    ST                  <= IDLE_ST;
  
                    OUT_REQ_TYPE        <= 'd0;
                    OUT_REQ_TYPE_VLD    <= 1'b0;
                    OUT_MAC_HEADER      <= 'd0;
                    OUT_ARP_HEADER      <= 'd0;
                    OUT_IP_HEADER       <= 'd0;
                    OUT_ICMP_HEADER     <= 'd0;
                    OUT_UDP_HEADER      <= 'd0;
                 
                    OVERTIME_CNT        <= 11'd0;
                    OVERTIME_EN         <= 1'b1;
                end     

default:    begin
                ST                  <= IDLE_ST;
         
                OUT_REQ_TYPE        <= 4'b0;
                OUT_REQ_TYPE_VLD    <= 1'b0;
                OUT_MAC_HEADER      <= OUT_MAC_HEADER;
                OUT_ARP_HEADER      <= OUT_ARP_HEADER;
                OUT_IP_HEADER       <= OUT_IP_HEADER;
                OUT_ICMP_HEADER     <= OUT_ICMP_HEADER;
                OUT_UDP_HEADER      <= OUT_UDP_HEADER;
                
                OVERTIME_CNT        <= 11'd0;
                OVERTIME_EN         <= 1'b0;
            end    

endcase
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
	    
	    .TRIG0			({44'b0,USER_DATA_TRANSFER_REQ,ST,REQ_STACK,OVERTIME_EN,REQ_DONE,OUT_BUF_STATE,OUT_REQ_TYPE,OUT_REQ_TYPE_VLD,IN_MESS_TYPE,IN_MESS_TYPE_VLD}), // IN BUS [63:0]
	    .TRIG1			(64'b0) // IN BUS [63:0]
	);
*/
endmodule
