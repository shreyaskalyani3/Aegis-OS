@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

set "isoname="
for %%f in (*.iso.part00) do (
    set "base=%%~nf"
    set "isoname=!base!"
)
if "%isoname%"=="" (
    for %%f in (*.iso.part*) do (
        set "base=%%~nf"
        set "isoname=!base!"
    )
)

if "%isoname%"=="" (
    echo [ERROR] No *.iso.part* files found in current directory.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo   Aegis OS -- Recombining Multi-Part ISO
echo ========================================================
echo Joining parts to create %isoname%...
copy /b %isoname%.part* %isoname%

echo.
echo Recombination complete.
if exist %isoname%.sha256 (
    echo.
    echo To verify integrity against SHA256 checksum:
    echo   certutil -hashfile %isoname% SHA256
    echo Compare the output with %isoname%.sha256.
)

echo.
echo [SUCCESS] %isoname% is ready!
pause
