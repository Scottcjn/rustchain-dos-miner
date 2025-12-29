# RustChain DOS Miner - Complete System Requirements

## System Components Needed

### 1. DOS Kernel (one of these)
| File | Source | Status |
|------|--------|--------|
| KERNEL.SYS | FreeDOS | ✅ Have |
| IBMBIO.COM + IBMDOS.COM | MS-DOS 4.0 | ✅ Have |

### 2. Command Interpreter
| File | Source | Status |
|------|--------|--------|
| COMMAND.COM | FreeDOS/MS-DOS | ✅ Have |

### 3. Memory Managers (for 386+)
| File | Purpose | Status |
|------|---------|--------|
| HIMEM.SYS | XMS extended memory | ❌ Need |
| EMM386.EXE | EMS expanded memory | ❌ Need |
| JEMM386.EXE | FreeDOS alternative | ❌ Need |

### 4. Network Stack
| File | Purpose | Status |
|------|---------|--------|
| NE2000.COM | NE2000 packet driver | ✅ Have |
| 3C509.COM | 3Com packet driver | ✅ Have |
| SMC_WD.COM | SMC/WD packet driver | ✅ Have |
| WATT-32 | TCP/IP library | ❌ Need (compile into miner) |
| WATTCP.CFG | Network config | ❌ Need to create |

### 5. Compiled Miner
| File | Purpose | Status |
|------|---------|--------|
| MINER.EXE | Compiled miner binary | ❌ Need DJGPP cross-compile |
| MINER.C | Source code | ✅ Have |
| ENTROPY.C | Entropy source | ✅ Have |

### 6. Configuration Files
| File | Purpose | Status |
|------|---------|--------|
| CONFIG.SYS | DOS config with HIMEM | ❌ Need to create |
| AUTOEXEC.BAT | Startup + network | ❌ Need to update |
| WATTCP.CFG | IP/DNS config | ❌ Need to create |
| MINER.CFG | Miner config | ❌ Need to create |

### 7. Utilities
| File | Purpose | Status |
|------|---------|--------|
| EDIT.COM | Text editor | ❌ Need |
| MORE.COM | Pager | ✅ Have (MS-DOS) |
| MEM.EXE | Memory check | ❌ Need |

## CONFIG.SYS Template (386+)
```
DEVICE=C:\DOS\HIMEM.SYS
DEVICE=C:\DOS\EMM386.EXE NOEMS
DOS=HIGH,UMB
FILES=30
BUFFERS=20
LASTDRIVE=Z
```

## CONFIG.SYS Template (8086/286)
```
FILES=20
BUFFERS=15
```

## AUTOEXEC.BAT Template
```
@ECHO OFF
PATH=C:\DOS;C:\DRIVERS;C:\RUSTCHN
SET WATTCP.CFG=C:\RUSTCHN\WATTCP.CFG

REM Load packet driver (NE2000 example)
LH C:\DRIVERS\NE2000 0x60 10 0x300

ECHO RustChain Miner Ready
ECHO Type MINER to start
```

## WATTCP.CFG Template
```
# Watt-32 TCP/IP Configuration
my_ip = dhcp
# Or static: my_ip = 192.168.1.100
# netmask = 255.255.255.0
# gateway = 192.168.1.1
# nameserver = 8.8.8.8
```

## Build Requirements

### To compile MINER.EXE:
1. **DJGPP** - DOS GCC cross-compiler
2. **Watt-32** - TCP/IP library for DJGPP
3. Cross-compile on Linux or build in DOSBox

### DJGPP Cross-Compile Command:
```bash
i586-pc-msdosdjgpp-gcc -O2 -o MINER.EXE MINER.C -lwatt
```

## Directory Structure on Disk
```
C:\
├── KERNEL.SYS (or IBMBIO.COM + IBMDOS.COM)
├── COMMAND.COM
├── CONFIG.SYS
├── AUTOEXEC.BAT
├── DOS\
│   ├── HIMEM.SYS
│   ├── EMM386.EXE
│   ├── EDIT.COM
│   └── MEM.EXE
├── DRIVERS\
│   ├── NE2000.COM
│   ├── 3C509.COM
│   ├── SMC_WD.COM
│   └── NETSETUP.BAT
└── RUSTCHN\
    ├── MINER.EXE      (compiled binary)
    ├── MINER.C        (source)
    ├── ENTROPY.C      (source)
    ├── WATTCP.CFG     (network config)
    ├── WALLET.TXT     (generated wallet)
    └── MINER.CFG      (miner settings)
```

## What We Need to Get

1. **HIMEM.SYS / EMM386.EXE** - From FreeDOS or MS-DOS
2. **DJGPP cross-compiler** - To compile miner on Linux
3. **Watt-32 library** - For TCP/IP in the miner
4. **Pre-compiled MINER.EXE** - Or build environment

## Minimum vs Full System

### Minimal (8086/286 - No networking)
- DOS kernel + COMMAND.COM
- MINER.EXE (compiled for 8086)
- Offline attestation to ATTEST.TXT

### Standard (386+ with networking)
- Full DOS with HIMEM
- Packet driver for NIC
- MINER.EXE with Watt-32
- Online attestation to node

### Full (486+ for best performance)
- DOS with EMM386
- Protected mode miner (DPMI)
- Full TCP/IP stack
- Real-time attestation
