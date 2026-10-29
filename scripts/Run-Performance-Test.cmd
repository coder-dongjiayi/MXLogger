@echo off
setlocal
title MXLogger Performance Diagnostics
echo MXLogger - complete 7-round performance comparison
echo Keep this window open until the report path is printed.
echo.
where pwsh.exe >nul 2>nul
if errorlevel 1 goto missing_powershell
pwsh.exe -NoLogo -NoProfile -File "%~dp0profile_windows_demo.ps1" -ExecutableDirectory "%~dp0." -ReportDirectory "%LOCALAPPDATA%\MXLoggerDemo\Profile"
set "mxlogger_result=%ERRORLEVEL%"
echo.
if not "%mxlogger_result%"=="0" echo Test failed. See the error above. Exit code: %mxlogger_result%
pause
exit /b %mxlogger_result%

:missing_powershell
echo PowerShell 7 ^(pwsh.exe^) is required for the complete comparison.
echo Install PowerShell 7, or double-click MXLoggerProfile.exe for a single-pass diagnostic.
echo.
pause
exit /b 1
