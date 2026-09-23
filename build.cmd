@echo off
setlocal

set "CERTO=%~1"
if "%CERTO%"=="" set "CERTO=C:\Users\robert\Desktop\root\Certo\target\release\certo.exe"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "DIST=%ROOT%\dist"

if not exist "%DIST%" mkdir "%DIST%"

"%CERTO%" check "%ROOT%\src\lume.cto"
if errorlevel 1 exit /b %errorlevel%

"%CERTO%" "%ROOT%\src\lume.cto" -o "%DIST%\lume.exe"
if errorlevel 1 exit /b %errorlevel%

"%DIST%\lume.exe" api > "%ROOT%\ai\lume-api.json"
exit /b %errorlevel%
