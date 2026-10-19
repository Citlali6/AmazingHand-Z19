@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" goto missing
".venv\Scripts\python.exe" host\app\main.py --mujoco %*
if errorlevel 1 pause
exit /b
:missing
echo Run setup_pc.bat first. Python 3.12 is required.
pause
exit /b 1
