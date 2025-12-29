@ECHO OFF
CLS
ECHO ==========================================
ECHO   RustChain DOS Miner - PowerElyan
ECHO   For 8086/286/386/486/Pentium Systems
ECHO ==========================================
ECHO.
ECHO Node: https://50.28.86.131
ECHO Dev Fee: 0.001 RTC/epoch to founder_dev_fund
ECHO.
ECHO This disk contains miner source code.
ECHO To build, you need DJGPP + Watt-32.
ECHO.
ECHO Source files in C:\RUSTCHN\
ECHO   - RUSTCHAI.C   Main miner
ECHO   - ENTROPY_.C   Hardware entropy
ECHO.
IF EXIST C:\RUSTCHN\MINER.EXE GOTO RUN
ECHO [!] Miner not compiled yet.
ECHO     Use DJGPP to compile:
ECHO     GCC -o MINER.EXE RUSTCHAI.C -lwatt
GOTO END
:RUN
ECHO Starting miner...
C:\RUSTCHN\MINER.EXE
:END
ECHO.
PAUSE
