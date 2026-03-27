set FILEPATH=%0
set SERVICE_NAME="4-Sync-Unload"
set SPRING_PROFILES_ACTIVE="test"
set SPRING_ROOT="%APP_HOME%/prime-to-commandor"
set SPRING_JAR="prime-to-commandor.jar"
set SPRING_APPLICATION_CLASS="com.petg.blois.Main"
set BATCH_KEY="unload"
# Durée en secondes
set BATCH_DELAY=7

if ""%1"" == ""install"" goto doInstall
if ""%1"" == ""start"" goto doStart
if ""%1"" == ""stop"" goto doStop
if ""%1"" == ""delete"" goto doDelete
if ""%1"" == ""run"" goto doRun

:doInstall
%FILEPATH% stop > NUL
%FILEPATH% delete > NUL
sc create %SERVICE_NAME% binPath="%FILEPATH% run"

goto doEnd

:doStart
sc start %SERVICE_NAME%

goto doEnd

:doStop
sc stop %SERVICE_NAME%

goto doEnd

:doDelete
%FILEPATH% stop > NUL
sc delete %SERVICE_NAME%

goto doEnd

:doRun
java -cp "%SPRING_ROOT%/%SPRING_JAR%;%SPRING_ROOT%" %SPRING_APPLICATION_CLASS%

goto doEnd

:doEnd
