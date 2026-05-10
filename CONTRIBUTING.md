# Contributing to RustChain DOS Miner

Thanks for helping improve RustChain DOS Miner. This project targets real DOS-era
hardware, so small, well-tested changes are much easier to review than broad
rewrites.

## Development Setup

1. Fork and clone the repository:

   ```bash
   git clone https://github.com/YOUR_USERNAME/rustchain-dos-miner.git
   cd rustchain-dos-miner
   ```

2. Install the tools needed for the area you are changing:

   - DJGPP for the 32-bit DOS miner path in `rustchain_dos_miner.c`.
   - Turbo C or another 16-bit DOS C compiler for limited real-mode changes.
   - NASM or a compatible assembler for `.ASM` files when working on low-level
     hardware routines.
   - mTCP or Watt-32 tooling when testing packet-driver networking.

3. Keep a clean working branch:

   ```bash
   git checkout -b fix/short-description
   ```

## What to Work On

Good first contributions include:

- Documentation improvements for DOS setup, packet drivers, and boot images.
- Compatibility notes for specific 8086, 286, 386, 486, or Pentium systems.
- Small fixes to `MINER.BAT`, `RTCMINE.BAT`, or `NETWORK.TXT`.
- Narrow C or assembly fixes with clear before/after behavior.

Avoid large rewrites unless an issue explicitly asks for them. The miner needs
to stay understandable on constrained systems and old toolchains.

## Code Style

- Prefer plain C that compiles under DOS-oriented compilers.
- Keep memory use low and avoid dynamic allocation unless it is necessary.
- Preserve compatibility comments around BIOS, timer, RTC, and packet-driver
  calls.
- Keep assembly routines small and document register inputs, outputs, and
  clobbers.
- Do not commit generated wallets, private keys, packet captures with secrets,
  or machine-specific configuration files.

## Verification

Run the smallest relevant checks for your change and include them in the PR:

- For docs-only changes, proofread the edited section and verify links or file
  names.
- For C changes, build with the intended DOS compiler when available.
- For batch-file changes, test command flow in DOSBox, FreeDOS, or real
  hardware.
- For networking changes, document the packet driver, IRQ, I/O address, and
  whether DHCP or static IP was used.

If you cannot test on vintage hardware, say so in the PR and describe the
emulator or static checks you used.

## Pull Requests

Before opening a PR:

- Keep the diff focused on one issue or one related improvement.
- Explain what changed and why.
- List the exact verification you ran.
- Mention any hardware, emulator, or compiler limitations.
- Update README or setup docs when behavior changes.

Use concise commit messages such as `fix: clarify packet driver setup` or
`docs: add FreeDOS verification notes`.

## Reporting Issues

When reporting a bug, include:

- CPU class and machine model if known.
- DOS version or FreeDOS version.
- Compiler or boot image used.
- Network card, packet driver, IRQ, and I/O address for networking issues.
- The exact command or batch file you ran.

These details help maintainers reproduce issues on hardware that may behave
differently from modern emulators.
