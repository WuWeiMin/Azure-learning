@echo off
chcp 65001 >nul
echo ================================================
echo  Mermaid MMD Right-Click Menu Setup
echo ================================================
echo.

:: ── 1. Create tool directory ─────────────────────
set TOOL_DIR=%USERPROFILE%\mermaid-tool
mkdir "%TOOL_DIR%" 2>nul
echo [1/3] Tool directory: %TOOL_DIR%

:: ── 2. Generate converter script mmd-to-png.bat ──
set CONVERTER=%TOOL_DIR%\mmd-to-png.bat

(
    echo @echo off
    echo chcp 65001 ^>nul
    echo set "INPUT=%%~1"
    echo set "OUTPUT=%%~dpn1.png"
    echo echo Converting: %%~nx1
    echo echo Output:     %%OUTPUT%%
    echo echo.
    echo mmdc -i "%%INPUT%%" -o "%%OUTPUT%%" -b white -s 2
    echo if %%errorlevel%%==0 ^(
    echo     echo.
    echo     echo Conversion successful!
    echo     echo File saved to: %%OUTPUT%%
    echo ^) else ^(
    echo     echo.
    echo     echo Conversion failed. Please check that mmdc is installed correctly.
    echo ^)
    echo echo.
    echo pause
) > "%CONVERTER%"

echo [2/3] Converter script created: %CONVERTER%

:: ── 3. Register right-click menu (current user, no admin required) ──
reg add "HKCU\Software\Classes\.mmd" /ve /d "mmdfile" /f >nul 2>&1
reg add "HKCU\Software\Classes\.mmd" /v "Content Type" /d "text/plain" /f >nul 2>&1

reg add "HKCU\Software\Classes\mmdfile" /ve /d "Mermaid Diagram" /f >nul 2>&1

reg add "HKCU\Software\Classes\mmdfile\shell" /ve /d "Convert to PNG" /f >nul 2>&1

reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /ve /d "Convert to PNG" /f >nul 2>&1
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /v "Icon" /d "msedge.exe,0" /f >nul 2>&1

reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG\command" /ve /d "cmd /c \"%CONVERTER%\" \"%%1\"" /f >nul 2>&1

echo [3/3] Right-click menu registered successfully

echo.
echo ================================================
echo  Setup complete!
echo  Right-click any .mmd file to see
echo  the "Convert to PNG" option.
echo  (If not visible, press F5 in Explorer
echo   or sign out and back in.)
echo ================================================
echo.
pause
