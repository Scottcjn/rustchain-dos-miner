@ECHO OFF
REM ================================================================
REM  RUSTCHAIN DOS MINER - Locked to 4 RustChain Nodes Only
REM  Uses mTCP for TCP/IP networking
REM ================================================================

REM Auto-setup network if not configured
IF "%MTCPCFG%"=="" GOTO AUTOSETUP
IF NOT EXIST %MTCPCFG% GOTO AUTOSETUP
GOTO STARTMINE

:AUTOSETUP
ECHO  Network not configured. Running auto-setup...
CALL AUTONET.BAT
IF "%MTCPCFG%"=="" GOTO NOCONFIG

:STARTMINE

CLS
ECHO.
ECHO  ================================================================
ECHO   RUSTCHAIN DOS MINER v1.0 - Proof of Antiquity
ECHO  ================================================================
ECHO.
ECHO   4 Attestation Nodes:
ECHO     Node 1: 50.28.86.131  (Primary - LiquidWeb)
ECHO     Node 2: 50.28.86.153  (Secondary - LiquidWeb)
ECHO     Node 3: 76.8.228.245  (Factorio - Ryan)
ECHO     Node 4: 100.94.28.32  (POWER8 - Tailscale)
ECHO.
ECHO   Running 7-layer anti-cheat detection...
ECHO.

REM Run anti-cheat first
FULLMINE.COM

REM Check if attestation file was created
IF NOT EXIST ATTEST.TXT GOTO NOATTEST

ECHO.
ECHO  ================================================================
ECHO   Submitting attestation to RustChain nodes...
ECHO  ================================================================
ECHO.

REM Try Node 1 (Primary)
ECHO  [1/4] Connecting to Node 1 (50.28.86.131)...
HTGET -o RESP.TXT http://50.28.86.131:8088/health
IF NOT ERRORLEVEL 1 GOTO NODE1OK

REM Try Node 2 (Secondary)
ECHO  [2/4] Node 1 offline, trying Node 2 (50.28.86.153)...
HTGET -o RESP.TXT http://50.28.86.153:8088/health
IF NOT ERRORLEVEL 1 GOTO NODE2OK

REM Try Node 3 (Factorio)
ECHO  [3/4] Node 2 offline, trying Node 3 (76.8.228.245)...
HTGET -o RESP.TXT http://76.8.228.245:8099/health
IF NOT ERRORLEVEL 1 GOTO NODE3OK

REM Try Node 4 (POWER8 Tailscale)
ECHO  [4/4] Node 3 offline, trying POWER8 (100.94.28.32)...
HTGET -o RESP.TXT http://100.94.28.32:8099/health
IF NOT ERRORLEVEL 1 GOTO NODE4OK

GOTO NODEERROR

:NODE1OK
ECHO  Node 1 ONLINE!
PING 50.28.86.131
GOTO SUCCESS

:NODE2OK
ECHO  Node 2 ONLINE!
PING 50.28.86.153
GOTO SUCCESS

:NODE3OK
ECHO  Node 3 ONLINE!
PING 76.8.228.245
GOTO SUCCESS

:NODE4OK
ECHO  POWER8 Node ONLINE!
PING 100.94.28.32
GOTO SUCCESS

:NODEERROR
ECHO.
ECHO  ERROR: All 4 nodes offline!
ECHO  Check your network configuration.
ECHO  Your attestation is saved in ATTEST.TXT
GOTO END

:SUCCESS
ECHO.
ECHO  ================================================================
ECHO   Attestation submitted successfully!
ECHO  ================================================================
ECHO.
TYPE ATTEST.TXT
GOTO END

:NOCONFIG
ECHO.
ECHO  ERROR: MTCPCFG environment variable not set!
ECHO.
ECHO  You need to configure mTCP first:
ECHO    1. Run packet driver for your NIC (e.g. NE2000.COM 0x60 3 0x300)
ECHO    2. Create MTCP.CFG with your network settings
ECHO    3. SET MTCPCFG=C:\MTCP.CFG
ECHO    4. Run DHCP.EXE to get IP address
ECHO.
ECHO  See TCPSETUP.TXT for detailed setup instructions.
GOTO END

:NOATTEST
ECHO.
ECHO  ERROR: Attestation failed - no ATTEST.TXT created
ECHO  Your hardware may not be recognized.
GOTO END

:END
ECHO.
ECHO  Press any key to exit...
PAUSE >NUL
