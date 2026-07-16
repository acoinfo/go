@echo off
REM Wrapper for SylixOS GCC to capture linker intermediate files

set REAL_GCC=D:\RealEvo\compiler\aarch64-sylixos-toolchain\bin\aarch64-sylixos-elf-gcc.exe
set CAPTURE_DIR=C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link

REM Create capture directory
if not exist "%CAPTURE_DIR%" mkdir "%CAPTURE_DIR%"

REM Log the full command
echo [%DATE% %TIME%] %* >> "%CAPTURE_DIR%\linker_cmd.txt"

REM Copy all .o and .res files to capture directory
for %%f in (%*) do (
    echo Checking: %%f >> "%CAPTURE_DIR%\linker_cmd.txt"
    if exist "%%f" (
        copy /Y "%%f" "%CAPTURE_DIR%\" >nul 2>&1
        echo   Copied: %%f >> "%CAPTURE_DIR%\linker_cmd.txt"
    )
)

REM Call the real GCC
"%REAL_GCC%" %*
exit /b %ERRORLEVEL%
