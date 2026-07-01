@echo off
chcp 65001 >nul
set "INPUT=%~1"
set "OUTPUT=%~dpn1.png"
echo ================================================
echo  Mermaid to PNG Converter
echo ================================================
echo Input : %INPUT%
echo Output: %OUTPUT%
echo.
call "C:\Users\E153773\AppData\Roaming\npm\mmdc.cmd" -i "%INPUT%" -o "%OUTPUT%" -b white -s 2
if %errorlevel%==0 (
    echo.
    echo Conversion successful!
    echo File saved to: %OUTPUT%
) else (
    echo.
    echo Conversion FAILED!
)
echo.
pause
