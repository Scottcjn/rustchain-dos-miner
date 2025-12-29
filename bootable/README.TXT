=========================================
RustChain DOS Miner - PowerElyan Edition
=========================================

This bootable disk contains the RustChain
cryptocurrency miner for vintage DOS systems.

SUPPORTED HARDWARE:
  - 8086/8088 (IBM PC/XT class)
  - 80286 (IBM AT class)
  - 80386/486/Pentium

REQUIREMENTS:
  - 640KB RAM minimum
  - NE2000-compatible network card
  - Packet driver loaded

ANTIQUITY BONUSES:
  - Pre-386: 3.5x rewards
  - 386/486: 2.5x rewards
  - Pentium: 2.0x rewards

FILES INCLUDED:
  C:\RUSTCHN\RUSTCHAI.C - Main miner source
  C:\RUSTCHN\ENTROPY_.C - Entropy collector
  C:\MINER.BAT          - Startup script

TO COMPILE (requires DJGPP):
  SET DJGPP=C:\DJGPP\DJGPP.ENV
  SET PATH=%PATH%;C:\DJGPP\BIN
  CD C:\RUSTCHN
  GCC -o MINER.EXE RUSTCHAI.C -lwatt

NETWORK SETUP:
  Load your packet driver first:
  NE2000 0x60 10 0x300
  (adjust IRQ and port for your card)

CONFIGURATION:
  Node URL: https://50.28.86.131
  Dev Fee:  0.001 RTC per epoch
  Dev Fund: founder_dev_fund

AUTO-WALLET:
  Wallet address auto-generated from:
  - BIOS signature
  - CPU type
  - Timer entropy
  Saved to C:\RUSTCHN\WALLET.TXT

GitHub: github.com/Scottcjn/rustchain-dos-miner
=========================================
