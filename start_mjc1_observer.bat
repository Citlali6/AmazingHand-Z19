@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" goto missing
".venv\Scripts\python.exe" fpga\mjc1_fpd\pc_observer.py
if errorlevel 1 pause
exit /b
:missing
echo Run setup_pc.bat first. See docs\migration\README.md for board setup.
pause
exit /b 1
