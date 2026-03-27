@ECHO OFF     

set SERVICE_DIR=%~dp0\services
set COMMANDOR1_EXE="%SERVICE_DIR%\commandor1.bat"
set COMMANDOR2_EXE="%SERVICE_DIR%\commandor2.bat"
set APACHE_EXE="%SERVICE_DIR%\apache.bat"
set SYNC_DELIVERY_EXE="%SERVICE_DIR%\sync_delivery.bat"
set SYNC_INVENTORY_EXE="%SERVICE_DIR%\sync_inventory.bat"
set STNC_PRODUCT_EXE="%SERVICE_DIR%\sync_product.bat"
set SYNC_UNLOAD_EXE="%SERVICE_DIR%\sync_unload.bat"

:doArgs
if ""%1"" == ""install"" goto doUp
if ""%1"" == ""start"" goto doUp
if ""%1"" == ""stop"" goto doDown
if ""%1"" == ""delete""  goto doDown

:doUp
call %COMMANDOR1_EXE% %1
call %COMMANDOR2_EXE% %1
call %APACHE_EXE% %1
goto doEnd

:doDown
call %APACHE_EXE% %1
call %COMMANDOR2_EXE% %1
call %COMMANDOR1_EXE% %1
goto doEnd

:doEnd
shift
if not "x%1x" == "xx" goto doArgs
timeout 1 > NUL
:end
