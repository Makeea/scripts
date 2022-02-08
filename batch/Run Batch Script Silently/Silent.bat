:: put this batch file in the same folder as the other scripts
@echo off
if "%1" == "1" goto else
echo start
call %0 1 > nul 2>&1
:: this will call your first batch file (>nul 2>&1) must stay
call copy-file.bat >nul 2>&1
echo done
:: this will call your 2nd batch file  (>nul 2>&1) must stay
call copy-file2.bat >nul 2>&1
goto done
:else:
echo done
:done: