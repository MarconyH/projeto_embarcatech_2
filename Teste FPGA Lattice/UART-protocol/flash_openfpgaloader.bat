@echo off
REM ============================================================
REM    Gravar bitstream com openFPGALoader no projeto blink_onboard_led
REM ============================================================
set OSSCAD=C:\oss-cad-suite
set TOP=top
set EXTENSION=sv
set LPF=colorlight_i9.lpf
set BOARD=colorlight-i9

call "%OSSCAD%\environment.bat"
cd %~dp0


yosys -p "read_verilog -sv %TOP%.%EXTENSION%; synth_ecp5 -top %TOP% -json %TOP%.json"

nextpnr-ecp5 --json "%TOP%.json" --textcfg "%TOP%.config" --lpf "%LPF%" --45k --package CABGA381 --speed 6

ecppack --compress "%TOP%.config" "%TOP%.bit"

openFPGALoader -b %BOARD% "%TOP%.bit"

del *.json *.config *.bit

echo ============================================================
echo ✅ Processo finalizado!
echo ============================================================
pause
