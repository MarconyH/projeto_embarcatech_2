@echo off
set OSSCAD=C:\oss-cad-suite
set TOP=uart_echo_colorlight_i9
set LPF=uart_colorlight_i9.lpf
set BOARD=colorlight-i9

cd /d %~dp0
call "%OSSCAD%\environment.bat"

setlocal enabledelayedexpansion
set "YOSYS_P=read_verilog -sv"
for %%f in (*.sv) do (
    set "YOSYS_P=!YOSYS_P! "%%~f""
)
set "YOSYS_P=!YOSYS_P! ; synth_ecp5 -top %TOP% -json %TOP%.json"

yosys -p "!YOSYS_P!"
nextpnr-ecp5 --json "%TOP%.json" --textcfg "%TOP%.config" --lpf "%LPF%" --45k --package CABGA381 --speed 6 --timing-allow-fail
ecppack --compress "%TOP%.config" "%TOP%.bit"
openFPGALoader -b %BOARD% "%TOP%.bit"

del "%TOP%.json" "%TOP%.config" "%TOP%.bit" 2>nul
endlocal