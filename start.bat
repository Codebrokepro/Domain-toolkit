@echo off
setlocal
cd /d "%~dp0"

set "PY=py"
where py >nul 2>nul || set "PY=python"

echo Installing dependencies...
"%PY%" -m pip install -r requirements.txt
if errorlevel 1 (
  echo.
  echo Failed to install dependencies. Is Python installed and on PATH?
  pause
  exit /b 1
)

start "" http://localhost:5000
echo.
echo Starting Geo-Domain Toolkit on http://localhost:5000
echo Close this window (or press Ctrl+C) to stop the server.
"%PY%" run.py

pause
