@ECHO OFF     

set CURRENT_DIR=%~dp0
set CURRENT_FILE=%~nx0
set SERVICE_NAME=1-Commandor2
rem !!! Attention des configurations de démarrage sont renseignées dans le fichier %PROJECT_HOME%\commandor2\install\commandor2.xml !!!

if ""%1"" == ""install"" goto doInstall
rem By default, use common.bat
call %CURRENT_DIR%common.bat %SERVICE_NAME% %1
goto doEnd

:doInstall
echo Install service %SERVICE_NAME%
call %CURRENT_DIR%common.bat %SERVICE_NAME% delete > NUL
timeout 1 > NUL
call %PROJECT_HOME%\commandor2\install\commandor2.exe install
goto doEnd

:doEnd

:end

EXIT /B %ERRORLEVEL%
