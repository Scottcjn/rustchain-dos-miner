# Contributing to RustChain DOS Miner

Thank you for your interest in contributing to the RustChain DOS Miner! This project enables mining RustChain cryptocurrency on vintage DOS systems (8086/286/386/486/Pentium). Your contributions help preserve computing history while participating in modern blockchain technology.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Submitting Changes](#submitting-changes)
- [Testing](#testing)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

This project is dedicated to providing a welcoming experience for everyone, from vintage computing enthusiasts to blockchain developers. We expect all contributors to:

- Be respectful and inclusive in all interactions
- Welcome newcomers and help them learn
- Focus on constructive criticism
- Respect different levels of expertise with vintage hardware
- Honor the spirit of preserving computing history

## Getting Started

### Prerequisites

To contribute to this project, you'll need:

**For Development:**
- A DOS-compatible environment (real hardware or emulator)
- OpenWatcom C/C++ compiler or Turbo C++ 3.0
- NASM assembler (for assembly optimizations)
- Git for version control

**For Testing:**
- DOSBox-X or 86Box emulator (recommended for development)
- Real vintage hardware (optional but valuable for final testing)
- Serial or network connectivity for pool communication

### Understanding the Project

The RustChain DOS Miner consists of:

- **Core Mining Engine**: SHA-256 and mining algorithm implementation
- **Network Stack**: Minimal TCP/IP for pool communication
- **Hardware Abstraction**: Support for various CPU architectures
- **Storage Layer**: Block and share data management
- **UI Layer**: Text-mode interface for DOS

## Development Environment

### Setting Up DOSBox-X

1. Install DOSBox-X:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install dosbox-x

   # macOS
   brew install dosbox-x

   # Windows
   # Download from https://dosbox-x.com/
   ```

2. Configure for target CPU:
   ```ini
   [cpu]
   core=normal
   cputype=386  # or 486, pentium_slow
   cycles=fixed 3000  # Adjust based on target

   [dos]
   ver=6.22

   [autoexec]
   mount c ~/dos-dev
   c:
   ```

3. Install OpenWatcom:
   - Download from https://openwatcom.org/
   - Install to `C:\WATCOM`
   - Add to PATH: `SET PATH=C:\WATCOM\BINW;%PATH%`

### Setting Up OpenWatcom

```bash
# Clone the repository
git clone https://github.com/Scottcjn/rustchain-dos-miner.git
cd rustchain-dos-miner

# Set environment variables (add to AUTOEXEC.BAT or run manually)
SET WATCOM=C:\WATCOM
SET PATH=%WATCOM%\BINW;%PATH%
SET INCLUDE=%WATCOM%\H;%INCLUDE%
```

### Building the Project

```bash
# Build for 386+
wmake -f Makefile.wat TARGET=386

# Build for 286
wmake -f Makefile.wat TARGET=286

# Build for 8086 (minimal features)
wmake -f Makefile.wat TARGET=8086
```

## How to Contribute

### Reporting Bugs

When reporting bugs, please include:

1. **Hardware/Emulator Details**:
   - CPU type (8086, 286, 386, 486, Pentium)
   - Clock speed
   - RAM amount
   - DOS version
   - Emulator name and version (if applicable)

2. **Problem Description**:
   - What you were doing
   - What happened
   - What you expected to happen
   - Error messages (exact text if possible)

3. **Reproduction Steps**:
   - Step-by-step instructions
   - Configuration files
   - Pool settings (without credentials)

4. **Additional Context**:
   - Screenshots (if possible)
   - Serial/Network logs
   - Memory dump (if crash)

### Suggesting Enhancements

Enhancement suggestions should include:

- Clear use case for vintage hardware users
- Performance impact assessment
- Memory requirements
- Compatibility considerations
- Proposed implementation approach

### Pull Request Process

1. **Fork the Repository**:
   ```bash
   gh repo fork Scottcjn/rustchain-dos-miner
   ```

2. **Create a Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

3. **Make Your Changes**:
   - Follow coding standards (see below)
   - Add tests if applicable
   - Update documentation

4. **Test Thoroughly**:
   - Test on target CPU architecture
   - Verify on both emulator and real hardware (if possible)
   - Check memory usage

5. **Commit Your Changes**:
   ```bash
   git add .
   git commit -m "feat: Add 486-specific optimizations

   - Implement CPUID detection
   - Add cache-friendly memory layout
   - Improve hash rate by 15% on 486DX2-66

   Tested on: 486DX2-66, DOS 6.22, 8MB RAM"
   ```

6. **Push and Create PR**:
   ```bash
   git push origin feature/your-feature-name
   gh pr create --title "feat: Description" --body "Details..."
   ```

## Coding Standards

### C Code Style

Follow these guidelines for C code:

```c
/* Function comments use C89 style */
/* Calculate SHA-256 hash of data
 * 
 * @param data Input data buffer
 * @param len Length of data in bytes
 * @param hash Output hash buffer (32 bytes)
 * @return 0 on success, -1 on error
 */
int sha256_hash(const uint8_t *data, size_t len, uint8_t *hash)
{
    /* Use 4-space indentation */
    /* Keep lines under 80 characters */
    
    /* Use explicit types for DOS compatibility */
    uint16_t i;
    
    /* Braces on same line (K&R style) */
    for (i = 0; i < len; i++) {
        /* Code here */
    }
    
    return 0;
}
```

**Key Rules:**
- Use C89/C90 standard for maximum compatibility
- Avoid C99 features (variable declarations in for loops, etc.)
- Use explicit types (`uint8_t`, `uint16_t`, `uint32_t`)
- Maximum line length: 80 characters
- Indentation: 4 spaces (no tabs)
- Comments: C-style `/* */` only (no `//`)

### Assembly Code Style

For assembly optimizations:

```nasm
; sha256_core.asm - SHA-256 core routines
; 
; Optimized for 386+ processors
; Preserves all registers except AX, DX

        .386
        .MODEL SMALL, C

        .CODE

; void sha256_transform(uint32_t *state, const uint8_t *block)
; 
; Parameters:
;   state - pointer to 8 uint32_t state values
;   block - pointer to 64-byte block
PUBLIC _sha256_transform
_sha256_transform PROC
        push    bp
        mov     bp, sp
        push    si
        push    di
        push    bx
        
        ; Implementation here
        
        pop     bx
        pop     di
        pop     si
        pop     bp
        ret
_sha256_transform ENDP

        END
```

**Assembly Guidelines:**
- Comment every function with purpose and register usage
- Preserve registers (push/pop) as per calling convention
- Use uppercase for instructions (consistency)
- Label names: lowercase with underscores
- Align loops on 16-byte boundaries for 486+

### Memory Management

DOS systems have limited memory. Follow these practices:

```c
/* Prefer static allocation for small buffers */
static uint8_t hash_buffer[32];

/* Use far pointers for data > 64KB */
uint8_t far *large_buffer;
large_buffer = farmalloc(1024L * 100L);  /* 100KB */

/* Always check allocations */
if (large_buffer == NULL) {
    printf("Error: Out of memory\n");
    return -1;
}

/* Free when done */
farfree(large_buffer);
```

**Memory Rules:**
- Minimize stack usage (keep under 4KB)
- Use near pointers when possible (faster)
- Use far pointers for >64KB data
- Check all allocations
- Free memory promptly

### CPU-Specific Optimizations

When adding optimizations, detect CPU at runtime:

```c
/* CPU detection */
typedef enum {
    CPU_8086 = 0,
    CPU_286,
    CPU_386,
    CPU_486,
    CPU_PENTIUM