# Contributing to RustChain DOS Miner

Welcome! This project brings RTC mining to vintage DOS machines (8086/286/386/486/Pentium).

## Development Setup

```bash
# Clone your fork
git clone https://github.com/MingYu5/rustchain-dos-miner.git
cd rustchain-dos-miner

# Examine source code
ls -la
cat RUSTCHN/MINER.C
```

## Supported Hardware

- 8086, 286, 386, 486, Pentium
- Requires DOS (FreeDOS or MS-DOS 4.0+)
- Network card with packet driver

## Code Style

- Turbo C / Borland C compatible
- Avoid modern C features
- Keep it simple for vintage compilers

## Running

### In DOSBox/DOSEMU
```bash
# Compile
tcc -mh miner.c

# Run
miner.exe --wallet YOUR_WALLET
```

### On Real Hardware
1. Write disk image to floppy/CD
2. Boot into DOS
3. Run `miner.exe --wallet YOUR_WALLET`

## Pull Request Process

1. Fork the repo
2. Create a feature branch
3. Test on real vintage hardware when possible
4. Open PR against `Scottcjn/rustchain-dos-miner:main`

## Notes

- This is a retrocomputing project - embrace the limitations!
- Real hardware mining is verified, emulators may be flagged
- Ensure code compiles with Turbo C++ 3.0 or compatible

Questions? Open an issue!
