@echo off

set dir=%CD%



set command="C:\Program Files (x86)\EMC\STPTools\StpRpt.exe"
if not exist %command% GOTO FILENOTFOUND

if exist metrics.txt set command=%command% -m metrics.txt 

for %%F in (  "%dir%\*.btp" ) do (
	%command%  -f "%%F" 
)


echo.
echo.
echo Complete!
GOTO END


:FILENOTFOUND
echo %command% not found. Please install STPTools from the SPEED website.
GOTO END

:END
pause 
