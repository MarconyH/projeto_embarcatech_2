@echo off

set files=uart_echo_colorlight_i9.sv uart_top.sv uart_rx.sv uart_tx.sv hough_transform.sv
set testbench=files_testbench/hough_transform_tb.sv

REM Compilar os arquivos e gerar o arquivo testbench.vvp
iverilog -g2012 -o testbench.vvp %testbench% %files%

REM Gerar o arquivo .vcd para o gtkwave (deve ser configurado no testbench)
vvp testbench.vvp

REM Usar o gtkwave para vizualizar as formas de onda
gtkwave *.vcd

REM Depois do uso os arquivos são apagados
del *.vvp *.vcd


pause
