`timescale 1ns / 1ps
/*
��������� �������� ����������� ������� �� ����� �������� ������� � ������ �� ������ �������� ������
*/
/*
PULSE2PULSE
#(
.CLOCK_RELATIONSHIP ()
)
PULSE2PULSE
(
.RST        (),
.CLK_IN     (),
.CLK_OUT    (),

.PULSE_IN   (),
.PULSE_OUT  ()
);
*/

module PULSE2PULSE
#(
parameter CLOCK_RELATIONSHIP = 3    // ��������� �������� ������ , ������ ����������� �� �������� ������. �������� CLK ����������� �������� �������� 125 ���, 
                                    // � CLK ��� ������� �� ������� ���� ������� 49 ���. 125/49 = 2.6 . ��������� �� 3.
)
(
input RST,
input CLK_IN,
input CLK_OUT,

input PULSE_IN,
output PULSE_OUT
);

reg [CLOCK_RELATIONSHIP - 1:0] IN_REG;   //
reg PULSE_OUT_reg;
 
always @(posedge CLK_IN or posedge RST)
if (RST) IN_REG[CLOCK_RELATIONSHIP - 1:0] <= 0;
else
    begin
        IN_REG[0]                          <= PULSE_IN;
        IN_REG[CLOCK_RELATIONSHIP - 1:1]   <= IN_REG[CLOCK_RELATIONSHIP - 2:0];
    end    

always @(posedge CLK_OUT or posedge RST)
if (RST) PULSE_OUT_reg <= 0;
else     PULSE_OUT_reg <= (IN_REG != 0);//IN_REG[1]; 

assign PULSE_OUT = PULSE_OUT_reg;
 
endmodule
