# RustChain DOS Miner - "Fossil Edition"

**For 8086/286/386/486/Pentium DOS systems**

*"Every vintage computer has historical potential"*

## Features

- **Auto-wallet generation** from hardware entropy
- **Hardware fingerprinting** (BIOS, CPU, timer, RTC)
- **3.5x antiquity multiplier** for ancient hardware!
- **Network attestation** via Watt-32 TCP/IP stack
- **Offline mode** for systems without networking
- **Dev Fee:** 0.001 RTC/epoch → founder_dev_fund

## Requirements

### Hardware
- 8086/286/386/486/Pentium CPU
- 640KB conventional memory minimum
- DOS 3.3+ or FreeDOS
- Network card with packet driver (optional)

### Compilation
- **DJGPP** (32-bit protected mode, recommended)
- **Watt-32** library for networking
- Or **Turbo C** for 16-bit real mode (limited features)

## Compilation

```bash
# With DJGPP + Watt-32
gcc -o miner.exe rustchain_dos_miner.c -lwatt

# Entropy collector only (Turbo C)
tcc entropy_dos.c
```

## Usage

```
C:\> MINER.EXE
```

1. First run generates wallet (saved to `WALLET.TXT`)
2. **BACKUP WALLET.TXT TO FLOPPY!**
3. Miner runs attestation loop every 10 minutes
4. Press 'S' for status, 'Q' or ESC to quit

## Files

| File | Description |
|------|-------------|
| `rustchain_dos_miner.c` | Full miner with networking |
| `entropy_dos.c` | Standalone entropy collector |
| `WALLET.TXT` | Generated wallet (SAVE THIS!) |
| `MINER.CFG` | Configuration file |

## Antiquity Multiplier

| CPU Class | Era | Multiplier |
|-----------|-----|------------|
| 8086/8088 | 1978-1982 | 4.0x |
| 286 | 1982-1985 | 3.8x |
| 386 | 1985-1989 | 3.5x |
| 486 | 1989-1993 | 3.0x |
| Pentium | 1993-1997 | 2.5x |

## Network Setup

1. Load packet driver for your NIC:
   ```
   NE2000.COM 0x60 3 0x300
   ```

2. Configure Watt-32 (wattcp.cfg):
   ```
   my_ip = dhcp
   ```

3. Run miner - it will auto-detect network

## Offline Mode

Without network, miner saves attestations to `ATTEST.TXT`.
Transfer this file to a networked computer to submit.

## License

Part of RustChain - Elyan Labs 2025
