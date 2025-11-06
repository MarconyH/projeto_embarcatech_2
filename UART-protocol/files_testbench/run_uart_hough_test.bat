@echo off
REM Script para testar integração UART + Hough Transform
REM Versão 3.0 - Sincronizado com main.c (formato empacotado)

echo ========================================
echo  TESTE DE INTEGRACAO: UART + HOUGH
echo  Versao 3.0 - Formato Empacotado
echo  Sincronizado com main.c atualizado
echo ========================================
echo.

REM Limpa arquivos anteriores
echo [1/4] Limpando arquivos anteriores...
if exist uart_hough_integration_tb.vvp del uart_hough_integration_tb.vvp
if exist uart_hough_integration.vcd del uart_hough_integration.vcd
if exist test_output.txt del test_output.txt

REM Compila testbench
echo [2/4] Compilando testbench...
iverilog -g2009 -o uart_hough_integration_tb.vvp ^
    ..\uart_rx.sv ^
    ..\uart_tx.sv ^
    ..\uart_top.sv ^
    ..\hough_transform.sv ^
    ..\uart_echo_colorlight_i9.sv ^
    uart_hough_integration_tb.sv

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Falha na compilacao!
    pause
    exit /b 1
)

echo [3/4] Compilacao bem-sucedida!
echo.

REM Executa simulação (Windows não tem 'tee', então redireciona e exibe depois)
echo [4/4] Executando simulacao...
echo ----------------------------------------
vvp uart_hough_integration_tb.vvp > test_output.txt 2>&1
type test_output.txt

echo.
echo ========================================
echo  ANALISE DOS RESULTADOS
echo ========================================

REM Busca por erros
echo.
echo [ERROS/AVISOS]
findstr /C:"ERRO" /C:"TIMEOUT" /C:"AVISO" test_output.txt

echo.
echo [COMUNICACAO]
findstr /C:"TX:" /C:"RX:" /C:"Bytes enviados" test_output.txt | find /C "TX:" > temp_tx.txt
set /p TX_COUNT=<temp_tx.txt
del temp_tx.txt
echo   Transmissoes TX: %TX_COUNT%

findstr /C:"TX:" /C:"RX:" /C:"Bytes recebidos" test_output.txt | find /C "RX:" > temp_rx.txt
set /p RX_COUNT=<temp_rx.txt
del temp_rx.txt
echo   Recepcoes RX: %RX_COUNT%

echo.
echo [RESULTADOS HOUGH]
findstr /C:"Linhas detectadas" /C:"Linha 0:" /C:"Linha 1:" test_output.txt

echo.
echo ========================================
echo  Arquivo VCD gerado: uart_hough_integration.vcd
echo  Log completo: test_output.txt
echo ========================================
echo.

pause