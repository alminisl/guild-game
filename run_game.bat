@echo off
echo Starting LOVE game...
cd /d "%~dp0"
"C:\Program Files\LOVE\love.exe" .
if errorlevel 1 (
    echo.
    echo Game exited with an error!
    pause
)
