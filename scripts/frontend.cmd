@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "ACTION=%~1"
set "PROFILE=%~2"

if "%ACTION%"=="" set "ACTION=restart"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%frontend.ps1" %ACTION% %PROFILE%
