@ECHO OFF     

set CURRENT_DIR=%~dp0
set SERVICE_NAME=1-Commandor1

if ""%1"" == ""install"" goto doInstall

call %CURRENT_DIR%\common.bat %SERVICE_NAME% %1
goto doEnd

:doInstall
echo Install service %SERVICE_NAME%
call %CURRENT_DIR%\common.bat %SERVICE_NAME% delete > NUL
timeout 1 > NUL
set SERVICE_STARTUP_MODE=auto
call %CATALINA_HOME%\bin\service.bat install %SERVICE_NAME%
goto doEnd

:doEnd

:end

EXIT /B %ERRORLEVEL%
