@ECHO OFF     

set CURRENT_DIR=%~dp0
set SERVICE_NAME=2-Apache

if ""%1"" == ""install"" goto doInstall

call %CURRENT_DIR%\common.bat %SERVICE_NAME% %1
goto doEnd

:doInstall
echo Install service %SERVICE_NAME%
call %CURRENT_DIR%\common.bat %SERVICE_NAME% delete > NUL
timeout 1 > NUL
call %APACHE_HOME%\bin\httpd.exe -k install -n %SERVICE_NAME%
goto doEnd

:doEnd

:end
