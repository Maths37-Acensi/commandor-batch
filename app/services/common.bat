@ECHO OFF     

if "x%1x" == "xx" (
	echo "Parameter service name is mandatory !"
	exit -2
)

set SERVICE_NAME=%1
shift

:doArgs
if ""%1"" == ""install"" goto doInstall
if ""%1"" == ""start"" goto doStart
if ""%1"" == ""stop"" goto doStop
if ""%1"" == ""delete"" goto doDelete
if ""%1"" == ""run"" goto doRun
goto doEnd

:doInstall
echo Install service %SERVICE_NAME%
call:mngsc delete > NUL
timeout 1 > NUL
call:create
goto doEnd

:doStart
echo Start service %SERVICE_NAME%
call:mngsc stop > NUL
timeout 1 > NUL
call:mngsc start
goto doEnd

:doStop
echo Stop service %SERVICE_NAME%
call:mngsc stop
goto doEnd

:doDelete
echo Delete service %SERVICE_NAME%
call:mngsc stop > NUL
timeout 1 > NUL
call:mngsc delete
goto doEnd

:doRun
echo Delete service %SERVICE_NAME%
call:mngsc stop > NUL
timeout 1 > NUL
call:mngsc delete
goto doEnd

:doEnd
shift
if not "x%1x" == "xx" goto doArgs
timeout 1 > NUL
:end

EXIT /B %ERRORLEVEL%

:: Functions

:mngsc
call sc %~1 %SERVICE_NAME%
EXIT /B 0
