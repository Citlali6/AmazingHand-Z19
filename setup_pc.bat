@echo off
setlocal
cd /d "%~dp0"
if exist ".venv\Scripts\python.exe" goto install
py -3.12 -m venv .venv
if errorlevel 1 goto fail
:install
".venv\Scripts\python.exe" -c "import sys; assert sys.version_info[:2] == (3, 12), 'Use Python 3.12; existing environment preserved'"
if errorlevel 1 goto fail
".venv\Scripts\python.exe" -m pip install -r sim\requirements-live.txt
if errorlevel 1 goto fail
".venv\Scripts\python.exe" tools\check_migration.py --runtime
if errorlevel 1 goto fail
echo PC environment ready. Run start_virtual_hand.bat.
pause
exit /b 0
:fail
echo Setup failed. Install Python 3.12 and review the error above.
echo Existing environments and board configuration have been preserved.
pause
exit /b 1
