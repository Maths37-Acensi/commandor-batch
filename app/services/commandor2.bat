@ECHO OFF     

set CURRENT_DIR=%~dp0
set SERVICE_NAME=1-Commandor2
rem !!! Attention des configurations de démarrage sont renseignées dans le fichier C:\app\commandorv2\commandorv2.xml !!!

if ""%1"" == ""install"" goto doInstall

call %CURRENT_DIR%\common.bat %SERVICE_NAME% %1
goto doEnd

:doInstall
echo Install service %SERVICE_NAME%
call %CURRENT_DIR%\common.bat %SERVICE_NAME% delete > NUL
timeout 1 > NUL
call %APP_HOME%\commandorv2\commandorv2.exe install
goto doEnd

:doEnd

:end

EXIT /B %ERRORLEVEL%
