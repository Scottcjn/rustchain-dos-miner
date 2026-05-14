# Contributing to RustChain DOS Miner

Thank you for your interest in contributing to the RustChain DOS Miner "Fossil Edition"!

## Project Overview

This project lets vintage 8086/286/386/486/Pentium computers mine on the RustChain blockchain. The older the hardware, the higher the antiquity multiplier.

## Development Setup

### Required Tools

- **DJGPP** — For 32-bit protected mode builds (recommended)
  - Download: https://www.delorie.com/djgpp/
  - Install with RHIDE or GCC directly

- **Watt-32** — TCP/IP stack for networking
  - Download: https://watt-32.home.xs4all.nl/
  - Configure `WATTCP.CFG` for your network

- **Turbo C** (optional) — For 16-bit real mode builds
  - Limited feature set (entropy collector only)

### Compilation

```bash
# 32-bit protected mode (recommended)
gcc -o miner.exe rustchain_dos_miner.c -lwatt

# 16-bit real mode (limited features)
tcc entropy_dos.c
```

### Testing

1. Write the image to a USB drive or CF card:
   ```bash
   dd if=rustchain-dos-miner.img of=/dev/sdX bs=4M
   ```

2. Boot on vintage hardware or emulator (DOSBox, 86Box, PCem)

3. Test the miner:
   ```
   C:\> MINER.EXE
   ```

## Code Style

- C89 compatible for maximum hardware compatibility
- Use `#ifdef __DJGPP__` for 32-bit specific code
- Keep memory usage under 640KB conventional memory
- Comment assembly sections thoroughly

## Submitting Changes

1. Fork the repository
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes with clear commit messages
4. Test on real vintage hardware when possible
5. Submit a pull request

## Ideas for Contributions

- Support for additional network card packet drivers
- Sound card entropy collection (Sound Blaster DMA)
- Serial port-based offline attestation submission
- Additional CPU detection for antiquity calculation
- Bug reports for specific hardware configurations

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project (Apache 2.0 for RustChain components).
