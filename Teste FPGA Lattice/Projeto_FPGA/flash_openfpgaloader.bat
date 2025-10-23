@echo off
set OSSCAD=C:\OSS-CAD-SUITE
set TOP=top_hough_uart
set LPF=colorlight_i9.lpf
set SV_FILES=top_hough_uart.sv uart_top.sv uart_rx.sv uart_tx.sv hough_tracker.sv sobel_processor.sv g_matrix.sv g_root_lut.sv frame_buffer_24bit.sv pixel_assembler_tx.sv

call "%OSSCAD%\environment.bat"
cd %~dp0

echo ===========================================
echo  Iniciando Construcao do Projeto FPGA (ECP5)
echo ===========================================
echo Modulo Top: %TOP%
echo Arquivos SystemVerilog: %SV_FILES%
echo Arquivo LPF: %LPF%
echo.

echo [1/4] Synth
:: Yosys ler todos os arquivos .sv
yosys -p "read_verilog -sv %SV_FILES%; synth_ecp5 -top %TOP% -json %TOP%.json"
if %errorlevel% neq 0 (
    echo Erro na sintese Yosys.
    goto :eof
)
echo Sintese Yosys concluida com sucesso.
echo.

echo [2/4] P e R
:: nextpnr-ecp5 com as especificacoes da Colorlight i9
nextpnr-ecp5 --json "%TOP%.json" --textcfg "%TOP%.config" --lpf "%LPF%" --45k --package CABGA381 --speed 6
if %errorlevel% neq 0 (
    echo Erro no Place & Route com nextpnr.
    goto :eof
)
echo Place & Route nextpnr concluido com sucesso.
echo.

echo [3/4] Pack
ecppack --compress "%TOP%.config" "%TOP%.bit"
if %errorlevel% neq 0 (
    echo Erro na geracao do bitstream com Ecppack.
    goto :eof
)
echo Bitstream '%TOP%.bit' gerado com sucesso.
echo.

echo [4/4] Program (RAM)
openFPGALoader -b colorlight-i9 "%TOP%.bit"
if %errorlevel% neq 0 (
    echo Erro ao programar a FPGA com openFPGALoader.
    goto :eof
)
echo FPGA programada com sucesso.
echo.

echo === DONE ===
endlocal
pause