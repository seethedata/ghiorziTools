@echo off
if EXIST "%CD%\symapi_db.bin" cmd /K "set SYMCLI_OFFLINE=1 & set SYMCLI_DB_FILE=%CD%\symapi_db.bin" & echo "%CD%\symapi_db.bin ready to query."
if NOT EXIST "%CD%\symapi_db.bin" echo No symapi_db.bin file found in %CD% directory & pause
