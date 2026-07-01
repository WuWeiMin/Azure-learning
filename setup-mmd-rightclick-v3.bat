@echo off
chcp 65001 >nul
echo ================================================
echo  Mermaid MMD Right-Click Menu Setup
echo ================================================
echo.

:: ── 1. Find mmdc full path ───────────────────────
set MMDC_PATH=%USERPROFILE%\AppData\Roaming\npm\mmdc.cmd
if not exist "%MMDC_PATH%" (
    echo [ERROR] mmdc not found at: %MMDC_PATH%
    echo Please make sure mermaid-cli is installed.
    pause
    exit /b 1
)
echo [1/4] Found mmdc at: %MMDC_PATH%

:: ── 2. Create tool directory ─────────────────────
set TOOL_DIR=%USERPROFILE%\mermaid-tool
mkdir "%TOOL_DIR%" 2>nul
echo [2/4] Tool directory: %TOOL_DIR%

:: ── 3. Generate converter script mmd-to-png.bat ──
set CONVERTER=%TOOL_DIR%\mmd-to-png.bat

(
    echo @echo off
    echo chcp 65001 ^>nul
    echo set "MMDC=%MMDC_PATH%"
    echo set "INPUT=%%~1"
    echo set "OUTPUT=%%~dpn1.png"
    echo set "LOGFILE=%%~dpn1.log"
    echo echo ================================================
    echo echo  Mermaid to PNG Converter
    echo echo ================================================
    echo echo Input : %%INPUT%%
    echo echo Output: %%OUTPUT%%
    echo echo.
    echo "%%MMDC%%" -i "%%INPUT%%" -o "%%OUTPUT%%" -b white -s 2 ^> "%%LOGFILE%%" 2^>^&1
    echo if %%errorlevel%%==0 ^(
    echo     echo Conversion successful^^!
    echo     echo File saved to: %%OUTPUT%%
    echo     del "%%LOGFILE%%" 2^>nul
    echo ^) else ^(
    echo     echo Conversion FAILED^^!
    echo     echo Error details saved to: %%LOGFILE%%
    echo     echo.
    echo     type "%%LOGFILE%%"
    echo ^)
    echo echo.
    echo pause
) > "%CONVERTER%"

echo [3/4] Converter script created: %CONVERTER%

:: ── 4. Register right-click menu ─────────────────
reg add "HKCU\Software\Classes\.mmd" /ve /d "mmdfile" /f >nul 2>&1
reg add "HKCU\Software\Classes\.mmd" /v "Content Type" /d "text/plain" /f >nul 2>&1
reg add "HKCU\Software\Classes\mmdfile" /ve /d "Mermaid Diagram" /f >nul 2>&1
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /ve /d "Convert to PNG" /f >nul 2>&1
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /v "Icon" /d "msedge.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG\command" /ve /d "cmd /c \"%CONVERTER%\" \"%%1\"" /f >nul 2>&1

echo [4/4] Right-click menu registered

echo.
echo ================================================
echo  Setup complete!
echo  Right-click any .mmd file to see
echo  "Convert to PNG" option.
echo ================================================
echo.
pause
