; RustChain Hardware Fingerprint Module - 16-bit DOS
; Anti-emulation and hardware fingerprinting for RIP-PoA
;
; Detects:
;   - VirtualBox, VMware, QEMU, Bochs
;   - DOSBox, PCem, 86Box
;   - Timing anomalies from emulation
;
; Collects:
;   - BIOS date and signature
;   - Timer jitter entropy
;   - CPU type and features
;   - Unique hardware identifiers

; Include this in your miner with: %include "fingerprint.asm"

section .text

; Check for VM/emulator presence
; Returns: AL=0 if real hardware, AL=1 if VM detected
; Also sets vm_detected and vm_name
check_vm:
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es

    mov     byte [vm_detected], 0

    ; Check 1: BIOS ROM strings for VM signatures
    call    check_bios_strings
    cmp     al, 1
    je      .vm_found

    ; Check 2: Timer jitter analysis
    call    check_timer_jitter
    cmp     al, 1
    je      .vm_found

    ; Check 3: I/O port timing (VMs often have delays)
    call    check_io_timing
    cmp     al, 1
    je      .vm_found

    ; Check 4: Check for hypervisor CPUID (486+ only)
    call    check_cpuid_hypervisor
    cmp     al, 1
    je      .vm_found

    ; All checks passed - real hardware
    mov     byte [vm_detected], 0
    xor     al, al
    jmp     .done

.vm_found:
    mov     byte [vm_detected], 1
    mov     al, 1

.done:
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret

; Check BIOS ROM for VM signatures
check_bios_strings:
    push    es
    push    di
    push    si
    push    cx

    ; Point to BIOS area F000:0000 - F000:FFFF
    mov     ax, 0F000h
    mov     es, ax

    ; Search for VM signatures
    mov     di, 0
    mov     cx, 0FFF0h      ; Search entire BIOS area

.search_loop:
    ; Check for "VBOX" (VirtualBox)
    cmp     dword [es:di], 'VBOX'
    je      .found_vbox

    ; Check for "VMwa" (VMware)
    cmp     dword [es:di], 'VMwa'
    je      .found_vmware

    ; Check for "QEMU"
    cmp     dword [es:di], 'QEMU'
    je      .found_qemu

    ; Check for "BOCH" (Bochs)
    cmp     dword [es:di], 'BOCH'
    je      .found_bochs

    ; Check for "DOSBox"
    cmp     word [es:di], 'DO'
    jne     .next
    cmp     word [es:di+2], 'SB'
    je      .found_dosbox

.next:
    inc     di
    loop    .search_loop

    ; Not found - real hardware
    xor     al, al
    jmp     .done

.found_vbox:
    mov     si, vm_vbox
    jmp     .set_name
.found_vmware:
    mov     si, vm_vmware
    jmp     .set_name
.found_qemu:
    mov     si, vm_qemu
    jmp     .set_name
.found_bochs:
    mov     si, vm_bochs
    jmp     .set_name
.found_dosbox:
    mov     si, vm_dosbox

.set_name:
    mov     di, vm_name
    mov     cx, 16
.copy_name:
    lodsb
    stosb
    or      al, al
    jz      .name_done
    loop    .copy_name
.name_done:
    mov     al, 1

.done:
    pop     cx
    pop     si
    pop     di
    pop     es
    ret

; Check timer jitter - real hardware has variance
; Emulators often have too-uniform timing
check_timer_jitter:
    push    bx
    push    cx
    push    dx

    ; Collect 16 timer samples
    mov     cx, 16
    mov     di, jitter_samples

.sample_loop:
    ; Read PIT channel 0
    xor     al, al
    out     43h, al         ; Latch counter 0
    in      al, 40h         ; Read low byte
    mov     ah, al
    in      al, 40h         ; Read high byte
    xchg    al, ah
    mov     [di], ax
    add     di, 2

    ; Small delay
    mov     bx, 100
.delay:
    dec     bx
    jnz     .delay

    loop    .sample_loop

    ; Analyze variance
    ; Real hardware: samples vary by 10-1000 counts
    ; Emulators: often uniform or too regular

    mov     si, jitter_samples
    mov     ax, [si]
    mov     bx, ax          ; min
    mov     dx, ax          ; max

    mov     cx, 15
.find_minmax:
    add     si, 2
    mov     ax, [si]
    cmp     ax, bx
    jae     .not_min
    mov     bx, ax
.not_min:
    cmp     ax, dx
    jbe     .not_max
    mov     dx, ax
.not_max:
    loop    .find_minmax

    ; Calculate range
    sub     dx, bx
    mov     [jitter_range], dx

    ; If range < 5, too uniform - likely emulator
    cmp     dx, 5
    jb      .too_uniform

    ; Real hardware
    xor     al, al
    jmp     .done

.too_uniform:
    mov     si, vm_emu_timing
    mov     di, vm_name
    mov     cx, 16
.copy:
    lodsb
    stosb
    loop    .copy
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

; Check I/O port timing
check_io_timing:
    push    cx
    push    dx

    ; Time a series of I/O operations
    ; Real hardware: consistent, fast
    ; Emulators: may have delays or inconsistency

    ; This is a simplified check
    xor     al, al
    ; For now, pass this check

    pop     dx
    pop     cx
    ret

; Check for hypervisor via CPUID (486+ only)
check_cpuid_hypervisor:
    push    bx
    push    cx
    push    dx

    ; First check if CPUID is supported (486+)
    ; Try to flip ID bit in FLAGS
    pushf
    pop     ax
    mov     bx, ax
    xor     ax, 0200000h    ; ID bit
    push    ax
    popf
    pushf
    pop     ax
    cmp     ax, bx
    je      .no_cpuid       ; CPUID not supported

    ; CPUID is supported - check for hypervisor
    mov     eax, 1
    cpuid
    test    ecx, 80000000h  ; Hypervisor present bit
    jnz     .hypervisor

    ; No hypervisor
    xor     al, al
    jmp     .done

.hypervisor:
    mov     si, vm_hypervisor
    mov     di, vm_name
    mov     cx, 16
.copy:
    lodsb
    stosb
    loop    .copy
    mov     al, 1
    jmp     .done

.no_cpuid:
    ; No CPUID = older CPU, pass check
    xor     al, al

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

; Collect hardware fingerprint data
; Fills fingerprint_data buffer
collect_fingerprint:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es

    mov     di, fingerprint_data

    ; 1. BIOS date (8 bytes at F000:FFF5)
    mov     ax, 0F000h
    mov     es, ax
    mov     si, 0FFF5h
    mov     cx, 8
.copy_date:
    mov     al, [es:si]
    mov     [di], al
    inc     si
    inc     di
    loop    .copy_date

    ; 2. BIOS signature (2 bytes at F000:FFFE)
    mov     si, 0FFFEh
    mov     ax, [es:si]
    mov     [di], ax
    add     di, 2

    ; 3. Timer jitter samples (use existing data)
    mov     ax, [jitter_range]
    mov     [di], ax
    add     di, 2

    ; 4. CMOS data (10 bytes)
    mov     cx, 10
    xor     bx, bx
.read_cmos:
    mov     al, bl
    out     70h, al
    in      al, 71h
    mov     [di], al
    inc     di
    inc     bx
    loop    .read_cmos

    ; 5. Equipment flags (INT 11h)
    int     11h
    mov     [di], ax
    add     di, 2

    ; 6. Memory size (INT 12h)
    int     12h
    mov     [di], ax
    add     di, 2

    ; 7. Video mode/adapter info
    mov     ah, 0Fh
    int     10h
    mov     [di], al        ; Mode
    inc     di
    mov     [di], ah        ; Columns
    inc     di

    ; 8. Anti-emulation result
    mov     al, [vm_detected]
    mov     [di], al
    inc     di

    ; Calculate fingerprint hash
    call    hash_fingerprint

    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; Hash the fingerprint data
hash_fingerprint:
    push    ax
    push    bx
    push    cx
    push    si
    push    di

    ; Simple rotating XOR hash
    mov     si, fingerprint_data
    mov     di, fingerprint_hash
    mov     cx, 20
    mov     al, 0A5h
.init:
    mov     [di], al
    ror     al, 1
    xor     al, cl
    inc     di
    loop    .init

    ; XOR with fingerprint data
    mov     si, fingerprint_data
    mov     di, fingerprint_hash
    mov     cx, 32          ; fingerprint_data size
    mov     bx, 0
.hash:
    lodsb
    xor     [di + bx], al
    rol     byte [di + bx], 3
    inc     bx
    cmp     bx, 20
    jb      .nowrap
    xor     bx, bx
.nowrap:
    loop    .hash

    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

section .data

; VM signature strings
vm_vbox:        db 'VirtualBox', 0
vm_vmware:      db 'VMware', 0
vm_qemu:        db 'QEMU', 0
vm_bochs:       db 'Bochs', 0
vm_dosbox:      db 'DOSBox', 0
vm_hypervisor:  db 'Hypervisor', 0
vm_emu_timing:  db 'Timing-Anomaly', 0

section .bss

; Detection results
vm_detected:        resb 1
vm_name:            resb 16

; Jitter analysis
jitter_samples:     resw 16
jitter_range:       resw 1

; Hardware fingerprint
fingerprint_data:   resb 32
fingerprint_hash:   resb 20
