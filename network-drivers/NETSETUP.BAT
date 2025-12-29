@ECHO OFF
CLS
ECHO ==========================================
ECHO   RustChain Miner - Network Setup
ECHO ==========================================
ECHO.
ECHO Select your network card:
ECHO.
ECHO   1. NE2000 / NE2000 compatible
ECHO   2. 3Com 3C509 (EtherLink III)
ECHO   3. 3Com 3C503 (EtherLink II)
ECHO   4. SMC / WD8003 / WD8013
ECHO   5. NE1000 (8-bit)
ECHO   6. Skip network setup
ECHO.
CHOICE /C:123456 /N "Enter choice (1-6): "
IF ERRORLEVEL 6 GOTO SKIP
IF ERRORLEVEL 5 GOTO NE1000
IF ERRORLEVEL 4 GOTO SMC
IF ERRORLEVEL 3 GOTO 3C503
IF ERRORLEVEL 2 GOTO 3C509
IF ERRORLEVEL 1 GOTO NE2000

:NE2000
ECHO.
ECHO Loading NE2000 driver...
ECHO Default: IRQ 10, I/O 0x300
C:\DRIVERS\NE2000 0x60 10 0x300
GOTO DONE

:3C509
ECHO.
ECHO Loading 3Com 3C509 driver...
C:\DRIVERS\3C509 0x60
GOTO DONE

:3C503
ECHO.
ECHO Loading 3Com 3C503 driver...
ECHO Default: IRQ 3, I/O 0x300, Memory 0xD000
C:\DRIVERS\3C503 0x60 3 0x300 0xD000
GOTO DONE

:SMC
ECHO.
ECHO Loading SMC/WD driver...
ECHO Default: IRQ 3, I/O 0x280, Memory 0xD000
C:\DRIVERS\SMC_WD 0x60 3 0x280 0xD000
GOTO DONE

:NE1000
ECHO.
ECHO Loading NE1000 driver...
ECHO Default: IRQ 3, I/O 0x300
C:\DRIVERS\NE1000 0x60 3 0x300
GOTO DONE

:SKIP
ECHO.
ECHO Network setup skipped.
ECHO Run NETSETUP again to configure network.
GOTO END

:DONE
ECHO.
ECHO [OK] Packet driver loaded on vector 0x60
ECHO.
ECHO Network ready! Run MINER to start mining.
ECHO.

:END
