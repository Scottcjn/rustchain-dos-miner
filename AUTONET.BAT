@ECHO OFF
REM ================================================================
REM  RUSTCHAIN AUTO-NETWORK SETUP
REM  Attempts DHCP, falls back to manual if it fails
REM ================================================================

CLS
ECHO.
ECHO  ================================================================
ECHO   RUSTCHAIN NETWORK AUTO-CONFIGURATION
ECHO  ================================================================
ECHO.

REM Check if packet driver is loaded by looking for MTCPCFG
IF "%MTCPCFG%"=="" GOTO LOADDRIVER

:CHECKDRIVER
REM Try to detect if packet driver is responding
ECHO  [1/4] Checking packet driver...
PKTTOOL > NUL 2>&1
IF ERRORLEVEL 1 GOTO LOADDRIVER
ECHO        Packet driver detected!
GOTO TRYDHCP

:LOADDRIVER
ECHO.
ECHO  No packet driver detected. Attempting to load...
ECHO.

REM Try common NIC drivers in order
ECHO  Trying NE2000 at 0x300...
IF EXIST DRIVERS\NE2000.COM DRIVERS\NE2000.COM 0x60 3 0x300 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO DRIVEROK

ECHO  Trying NE2000 at 0x320...
IF EXIST DRIVERS\NE2000.COM DRIVERS\NE2000.COM 0x60 5 0x320 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO DRIVEROK

ECHO  Trying 3C509...
IF EXIST DRIVERS\3C509.COM DRIVERS\3C509.COM 0x60 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO DRIVEROK

ECHO  Trying SMC/WD at 0x280...
IF EXIST DRIVERS\SMC_WD.COM DRIVERS\SMC_WD.COM 0x60 5 0x280 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO DRIVEROK

GOTO NODRIVER

:DRIVEROK
ECHO        Packet driver loaded successfully!

REM Set config path if not set
IF "%MTCPCFG%"=="" SET MTCPCFG=C:\MTCP.CFG

REM Create minimal config for DHCP
ECHO PACKETINT 0x60 > %MTCPCFG%
ECHO HOSTNAME DOSMINER >> %MTCPCFG%

:TRYDHCP
ECHO.
ECHO  [2/4] Attempting DHCP...
ECHO.

REM Run DHCP with timeout
DHCP
IF ERRORLEVEL 1 GOTO DHCPFAIL

ECHO.
ECHO        DHCP successful!
GOTO TESTNET

:DHCPFAIL
ECHO.
ECHO  ================================================================
ECHO   DHCP FAILED - Manual Configuration Required
ECHO  ================================================================
ECHO.
ECHO  Enter your network settings (or press ENTER for defaults):
ECHO.

REM Prompt for IP address
SET /P IPADDR="  IP Address [192.168.1.100]: "
IF "%IPADDR%"=="" SET IPADDR=192.168.1.100

REM Prompt for netmask
SET /P NETMASK="  Netmask [255.255.255.0]: "
IF "%NETMASK%"=="" SET NETMASK=255.255.255.0

REM Prompt for gateway
SET /P GATEWAY="  Gateway [192.168.1.1]: "
IF "%GATEWAY%"=="" SET GATEWAY=192.168.1.1

REM Prompt for DNS
SET /P NAMESERVER="  DNS Server [8.8.8.8]: "
IF "%NAMESERVER%"=="" SET NAMESERVER=8.8.8.8

ECHO.
ECHO  Writing configuration...

REM Write static config
ECHO PACKETINT 0x60 > %MTCPCFG%
ECHO HOSTNAME DOSMINER >> %MTCPCFG%
ECHO IPADDR %IPADDR% >> %MTCPCFG%
ECHO NETMASK %NETMASK% >> %MTCPCFG%
ECHO GATEWAY %GATEWAY% >> %MTCPCFG%
ECHO NAMESERVER %NAMESERVER% >> %MTCPCFG%

ECHO        Static IP configured: %IPADDR%

:TESTNET
ECHO.
ECHO  [3/4] Testing network connectivity...
ECHO.

REM Test connection to primary node
ECHO  Pinging RustChain Node 1 (50.28.86.131)...
PING 50.28.86.131 -n 1 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO NETOK

ECHO  Node 1 unreachable, trying Node 2...
PING 50.28.86.153 -n 1 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO NETOK

ECHO  Node 2 unreachable, trying Node 3...
PING 76.8.228.245 -n 1 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO NETOK

ECHO  Node 3 unreachable, trying POWER8...
PING 100.94.28.32 -n 1 > NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO NETOK

GOTO NETFAIL

:NETOK
ECHO.
ECHO        Network OK! RustChain node reachable.
ECHO.
ECHO  [4/4] Network setup complete!
ECHO.
ECHO  ================================================================
ECHO   READY TO MINE
ECHO  ================================================================
ECHO.
ECHO  Run RTCMINE.BAT to start mining, or MINELOOP.COM for continuous.
ECHO.
GOTO END

:NETFAIL
ECHO.
ECHO  ================================================================
ECHO   WARNING: No RustChain nodes reachable!
ECHO  ================================================================
ECHO.
ECHO  Network is configured but cannot reach any nodes.
ECHO  Possible causes:
ECHO    - No internet connection
ECHO    - Firewall blocking traffic
ECHO    - Wrong gateway address
ECHO.
ECHO  You can still run MINELOOP.COM for offline attestation.
ECHO  Submit ATTEST.TXT manually when network is available.
ECHO.
GOTO END

:NODRIVER
ECHO.
ECHO  ================================================================
ECHO   ERROR: Could not load packet driver!
ECHO  ================================================================
ECHO.
ECHO  No supported network card detected.
ECHO.
ECHO  Please load your packet driver manually:
ECHO    DRIVERS\NE2000.COM 0x60 [IRQ] [IOADDR]
ECHO.
ECHO  Then run AUTONET.BAT again.
ECHO.
ECHO  See TCPSETUP.TXT for detailed instructions.
ECHO.

:END
ECHO  Press any key to continue...
PAUSE > NUL
