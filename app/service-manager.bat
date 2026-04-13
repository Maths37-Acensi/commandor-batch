@ECHO OFF     

set SERVICE_DIR=%~dp0\service
set COMMANDOR1_EXE=%SERVICE_DIR%\commandor1.bat
set COMMANDOR2_EXE=%SERVICE_DIR%\commandor2.bat
set APACHE_EXE=%SERVICE_DIR%\apache.bat
set SYNC_DELIVERY_EXE=%SERVICE_DIR%\sync-delivery.bat
set SYNC_INVENTORY_EXE=%SERVICE_DIR%\sync-inventory.bat
set SYNC_PRODUCT_EXE=%SERVICE_DIR%\sync-product.bat
set SYNC_UNLOAD_EXE=%SERVICE_DIR%\sync-unload.bat

:doArgs
if ""%1"" == ""install"" goto doUp
if ""%1"" == ""start"" goto doUp
if ""%1"" == ""stop"" goto doDown
if ""%1"" == ""delete"" goto doDown

:doUp
call %SYNC_DELIVERY_EXE% %1
call %SYNC_INVENTORY_EXE% %1
call %SYNC_PRODUCT_EXE% %1
call %SYNC_UNLOAD_EXE% %1
call %COMMANDOR1_EXE% %1
call %COMMANDOR2_EXE% %1
call %APACHE_EXE% %1
goto doEnd

:doDown
call %APACHE_EXE% %1
call %COMMANDOR2_EXE% %1
call %COMMANDOR1_EXE% %1
call %SYNC_DELIVERY_EXE% %1
call %SYNC_INVENTORY_EXE% %1
call %SYNC_PRODUCT_EXE% %1
call %SYNC_UNLOAD_EXE% %1
goto doEnd

:doEnd
shift
if not "x%1x" == "xx" goto doArgs
timeout 1 > NUL
:end
