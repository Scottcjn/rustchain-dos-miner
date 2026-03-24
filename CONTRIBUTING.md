# Contributing to RustChain DOS Miner

Thank you for your interest in contributing to the RustChain DOS Miner! This project preserves cryptocurrency mining history by implementing a RustChain miner for vintage x86 processors (8086/286/386/486/Pentium) running DOS.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Assembly Guidelines](#assembly-guidelines)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [RTC Bounty Program](#rtc-bounty-program)

## Code of Conduct

This project is part of the RustChain ecosystem. We expect all contributors to:
- Be respectful and constructive in all interactions
- Focus on preserving computing history while advancing the project
- Help newcomers learn x86 assembly and DOS programming
- Respect the vintage nature of the target platforms

## Getting Started

### Prerequisites

To contribute to this project, you'll need:

1. **DOS Environment**: Either real hardware or an emulator
   - [DOSBox-X](https://dosbox-x.com/) (recommended for development)
   - [86Box](https://86box.github.io/) for accurate vintage hardware emulation
   - Real vintage PC (8086/286/386/486/Pentium)

2. **Assembly Tools**:
   - NASM (Netwide Assembler) 2.15+ or
   - MASM 6.11 or earlier for authentic DOS development
   - TASM (Turbo Assembler) 5.0+ as alternative

3. **Git** with Unix line ending support

### Repository Structure

```
rustchain-dos-miner/
├── src/                    # Source code
│   ├── miner.asm          # Main miner implementation
│   ├── hash.asm           # Hash computation routines
│   ├── network.asm        # Network/serial communication
│   └── utils.asm          # Utility functions
├── include/               # Header files and macros
├── tests/                 # Test cases
├── docs/                  # Documentation
├── tools/                 # Build and utility scripts
└── examples/              # Example configurations
```

## Development Environment

### Setting Up DOSBox-X

1. Install DOSBox-X for your platform
2. Create a development configuration:
   ```ini
   [cpu]
   core=normal
   cputype=386
   cycles=30000

   [dos]
   xms=true
   ems=true
   umb=true

   [autoexec]
   mount c ~/rustchain-dos-miner
   c:
   set PATH=c:\tools;%PATH%
   ```

3. Install your chosen assembler in the mounted drive

### Building the Project

```batch
; Using NASM
nasm -f bin -o miner.com src/miner.asm

; Using MASM
masm src/miner.asm;
link miner.obj;
exe2bin miner.exe miner.com
```

## How to Contribute

### Finding Issues

Check the [issue tracker](https://github.com/Scottcjn/rustchain-dos-miner/issues) for:
- `good first issue` — beginner-friendly tasks
- `help wanted` — areas where maintainers need assistance
- `optimization` — performance improvements
- `documentation` — docs and guides
- `hardware-support` — new CPU/platform support

### Types of Contributions

We welcome:
- **Code**: Assembly optimizations, new features, bug fixes
- **Documentation**: Guides, tutorials, historical context
- **Testing**: Test cases, hardware compatibility reports
- **Tools**: Build scripts, development utilities
- **Research**: Historical accuracy, period-correct implementations

## Coding Standards

### Assembly Style Guide

1. **Comments**:
   ```asm
   ;=============================================================================
   ; FUNCTION: compute_hash
   ; PURPOSE:  Calculate RustChain hash for a given nonce
   ; INPUT:    SI = pointer to block header
   ;           CX = nonce value
   ; OUTPUT:   AX = hash result (0 = success, non-zero = error)
   ; DESTROYS: AX, BX, DX, DI
   ;=============================================================================
   ```

2. **Indentation**:
   - Labels: Column 1, no indentation
   - Instructions: Column 17 (tab or 16 spaces)
   - Operands: Column 33 (aligned)
   - Comments: Column 49 (semicolon + space)

3. **Naming Conventions**:
   - Procedures: `lowercase_with_underscores`
   - Constants: `UPPERCASE_WITH_UNDERSCORES`
   - Macros: `PascalCase`
   - Labels: `.local_label` (local), `global_label` (global)

4. **Example**:
   ```asm
   ;-----------------------------------------------------------------------------
   ; Main mining loop
   ;-----------------------------------------------------------------------------
   miner_loop:
       call    check_keyboard      ; Allow user interrupt
       jc      .exit               ; Carry set = exit requested

       mov     cx, [current_nonce]
       call    compute_hash
       test    ax, ax
       jz      .hash_found

       inc     [current_nonce]
       jmp     miner_loop

   .hash_found:
       call    submit_solution
       jmp     miner_loop

   .exit:
       ret
   ```

### Portability Guidelines

- Support 8086 as baseline (16-bit real mode)
- Use 386+ instructions only when guarded by CPU detection
- Avoid BIOS calls when possible (use direct hardware access)
- Document any hardware-specific optimizations

## Assembly Guidelines

### Memory Management

DOS provides limited memory. Follow these practices:

1. **Use COM format** when possible (single segment, < 64KB)
2. **Minimize stack usage** — DOS default stack is small
3. **Prefer static allocation** over dynamic
4. **Document memory layout**:
   ```asm
   ; Memory Map:
   ; 0000:0000 - Program start (CS=DS=ES=SS)
   ; 0100:0000 - Block header buffer (80 bytes)
   ; 0150:0000 - Hash workspace (64 bytes)
   ; 0190:0000 - Network buffer (256 bytes)
   ```

### Optimization Priorities

1. **Size first** — Fit in available memory
2. **Speed second** — Optimize critical paths
3. **Compatibility third** — Support widest hardware range

### Hardware Abstraction

```asm
; CPU Detection Example
detect_cpu:
    pushf
    pop     ax
    mov     bx, ax
    xor     ax, 0x4000          ; Try to flip NT bit (386+)
    push    ax
    popf
    pushf
    pop     ax
    cmp     ax, bx
    je      .is_8086_286        ; No change = 8086/286

    ; 386+ detected
    mov     [cpu_type], CPU_386
    jmp     .done

.is_8086_286:
    mov     [cpu_type], CPU_8086

.done:
    ret
```

## Testing

### Test Categories

1. **Unit Tests**: Individual function validation
2. **Integration Tests**: Full mining workflow
3. **Hardware Tests**: Real vintage hardware validation
4. **Compatibility Tests**: Cross-assembler verification

### Writing Tests

Create test files in `tests/`:

```asm
; tests/test_hash.asm
; Test hash computation with known inputs

%include "../include/test_framework.inc"

test_hash_known_values:
    mov     si, test_block_1
    mov     cx, 0x1234
    call    compute_hash

    assert_eq ax, EXPECTED_RESULT, "Hash computation failed"
    ret
```

### Reporting Hardware Compatibility

When testing on real hardware, include:
- CPU model and speed (e.g., Intel 486 DX2-66)
- RAM amount
- DOS version
- Network card (if applicable)
- Hash rate achieved
- Any issues encountered

## Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** with clear, focused commits
4. **Test** on DOSBox-X and document real hardware testing if possible
5. **Update documentation** if needed
6. **Submit PR** with:
   - Clear description of changes
   - DOSBox-X test results
   - Real hardware test results (if applicable)
   - Performance impact (if applicable)

### Commit Message Format

```
category: brief description

Detailed explanation of what changed and why.

- Specific change 1
- Specific change 2

Tested on: DOSBox-X 386/33, 86Box 486/66
```

Categories:
- `feat:` — New feature