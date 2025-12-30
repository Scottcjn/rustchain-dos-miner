@ECHO OFF
CLS
ECHO.
ECHO  ================================================================
ECHO   RUSTCHAIN DOS MINER - Proof of Antiquity (RIP-PoA)
ECHO  ================================================================
ECHO.
ECHO   Available Tools:
ECHO   ----------------
ECHO   MINER.COM     - Generate wallet + show mining info
ECHO   ANTICHEAT.COM - 7-layer anti-emulation detection
ECHO   HWSCRAPE.COM  - Hardware info scraper (BIOS, ISA, serials)
ECHO.
ECHO   For full RTC rewards, ALL 7 anti-cheat layers must pass!
ECHO   Running on emulator = 0.000000001x reward multiplier
ECHO.
ECHO  ================================================================
ECHO.
ECHO   Press 1 for Quick Mine (wallet generation)
ECHO   Press 2 for Anti-Cheat Scan (7-layer detection)
ECHO   Press 3 for Hardware Scan (BIOS/ISA info)
ECHO   Press 4 for Full Attestation (all checks)
ECHO   Press Q to Quit
ECHO.
CHOICE /C:1234Q /N "  Your choice: "
IF ERRORLEVEL 5 GOTO END
IF ERRORLEVEL 4 GOTO FULL
IF ERRORLEVEL 3 GOTO HWSCAN
IF ERRORLEVEL 2 GOTO ANTICHEAT
IF ERRORLEVEL 1 GOTO MINE
GOTO END

:MINE
CLS
MINER.COM
PAUSE
GOTO END

:ANTICHEAT
CLS
ANTICHEAT.COM
PAUSE
GOTO END

:HWSCAN
CLS
HWSCRAPE.COM
PAUSE
GOTO END

:FULL
CLS
ECHO.
ECHO  Running full attestation sequence...
ECHO.
ECHO  [Step 1/3] Hardware Scan...
HWSCRAPE.COM
ECHO.
ECHO  [Step 2/3] Anti-Cheat Detection...
ANTICHEAT.COM
ECHO.
ECHO  [Step 3/3] Wallet Generation...
MINER.COM
ECHO.
ECHO  ================================================================
ECHO   Attestation complete!
ECHO   Check WALLET.TXT for your wallet address.
ECHO   Submit fingerprint hash to node for verification.
ECHO  ================================================================
PAUSE
GOTO END

:END
