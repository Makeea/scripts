:: run as Admin
:: Stops the print spooler, deletes all print jobs, and starts the print spooler.
@echo off
echo.
echo Purging the print queue...
net stop Spooler
echo Deleting all print jobs...
ping localhost -n 4 > nul
del /q %SystemRoot%\system32\spool\printers\*.*  /Q /F /S
net start Spooler
echo Done!
ping localhost -n 4 > nul