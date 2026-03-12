:: ==================================================================================
:: NAME     : MKdosc server start
:: ==================================================================================
@echo off

set SERVER_PORT=9006
set IP_ADDRESS=127.0.0.1


:: Start MKdocs server
:: /************************************************************************************/
echo.
ECHO ===== Starting MKdocs server =====
echo.

ECHO --- CD to MKdocs foder ---
call cd c:/Build/construction_plan/
echo.


ECHO --- MKdocs server run ---
cmd.exe /c start /min cmd /k mkdocs serve --livereload -a %IP_ADDRESS%:%SERVER_PORT%
:: call start cmd /k mkdocs serve -a %IP_ADDRESS%:%SERVER_PORT%
echo.
:: /************************************************************************************/

:: mkdocs serve -a 127.0.0.1:9006