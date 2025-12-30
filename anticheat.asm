; RustChain Anti-Cheat Module - 7 Layer Detection
; Detects ALL emulation: DOSBox, PCem, 86Box, Bochs, QEMU, VMware, VirtualBox, Proxmox
; Even catches "real DOS" running inside a VM!
;
; Assembles with: nasm -f bin -o ANTICHEAT.COM anticheat.asm
;
; === 7 LAYER DETECTION ===
; Layer 1: BIOS ROM Signature Scan
; Layer 2: Timer Jitter Entropy Analysis
; Layer 3: I/O Port Timing Fingerprint
; Layer 4: Memory Timing Patterns
; Layer 5: CPUID Hypervisor Detection
; Layer 6: Hardware Interrupt Timing
; Layer 7: Entropy Quality Assessment
;
; The server requires ALL 7 layers to pass for full antiquity bonus!

org 100h

section .text

start:
    mov     ax, 0003h
    int     10h

    mov     ah, 09h
    mov     dx, banner
    int     21h

    ; Initialize results
    mov     byte [total_score], 0
    mov     byte [layers_passed], 0

    ; === LAYER 1: BIOS ROM Signature Scan ===
    mov     ah, 09h
    mov     dx, layer1_msg
    int     21h

    call    layer1_bios_scan
    mov     [layer1_result], al
    cmp     al, 0
    jne     .layer1_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer2
.layer1_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    mov     si, detected_emu
    call    print_string

    ; === LAYER 2: Timer Jitter Analysis ===
.layer2:
    mov     ah, 09h
    mov     dx, layer2_msg
    int     21h

    call    layer2_timer_jitter
    mov     [layer2_result], al
    mov     [jitter_variance], bx
    cmp     al, 0
    jne     .layer2_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer3
.layer2_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    mov     ah, 09h
    mov     dx, jitter_low_msg
    int     21h

    ; === LAYER 3: I/O Port Timing ===
.layer3:
    mov     ah, 09h
    mov     dx, layer3_msg
    int     21h

    call    layer3_io_timing
    mov     [layer3_result], al
    cmp     al, 0
    jne     .layer3_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer4
.layer3_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    mov     ah, 09h
    mov     dx, timing_uniform_msg
    int     21h

    ; === LAYER 4: Memory Timing ===
.layer4:
    mov     ah, 09h
    mov     dx, layer4_msg
    int     21h

    call    layer4_memory_timing
    mov     [layer4_result], al
    cmp     al, 0
    jne     .layer4_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer5
.layer4_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h

    ; === LAYER 5: CPUID Hypervisor ===
.layer5:
    mov     ah, 09h
    mov     dx, layer5_msg
    int     21h

    call    layer5_cpuid_hypervisor
    mov     [layer5_result], al
    cmp     al, 0
    jne     .layer5_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer6
.layer5_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    mov     si, hypervisor_name
    call    print_string

    ; === LAYER 6: Interrupt Timing ===
.layer6:
    mov     ah, 09h
    mov     dx, layer6_msg
    int     21h

    call    layer6_interrupt_timing
    mov     [layer6_result], al
    cmp     al, 0
    jne     .layer6_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .layer7
.layer6_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h

    ; === LAYER 7: Entropy Quality ===
.layer7:
    mov     ah, 09h
    mov     dx, layer7_msg
    int     21h

    call    layer7_entropy_quality
    mov     [layer7_result], al
    mov     [entropy_score], bx
    cmp     al, 0
    jne     .layer7_fail
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    jmp     .summary
.layer7_fail:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    mov     ah, 09h
    mov     dx, entropy_low_msg
    int     21h

    ; === SUMMARY ===
.summary:
    mov     ah, 09h
    mov     dx, summary_header
    int     21h

    ; Show layers passed
    mov     ah, 09h
    mov     dx, layers_lbl
    int     21h
    mov     al, [layers_passed]
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     ah, 09h
    mov     dx, of_7_msg
    int     21h

    ; Compute final score
    ; Full pass = 100, each layer = ~14 points
    mov     al, [layers_passed]
    mov     bl, 14
    mul     bl
    cmp     al, 100
    jbe     .score_ok
    mov     al, 100
.score_ok:
    mov     [total_score], al

    ; Display score
    mov     ah, 09h
    mov     dx, score_lbl
    int     21h
    movzx   ax, byte [total_score]
    call    print_decimal
    mov     ah, 09h
    mov     dx, percent_msg
    int     21h

    ; Final verdict
    cmp     byte [layers_passed], 7
    je      .real_hardware
    cmp     byte [layers_passed], 5
    jae     .suspicious
    jmp     .emulated

.real_hardware:
    mov     ah, 09h
    mov     dx, verdict_real
    int     21h
    jmp     .done

.suspicious:
    mov     ah, 09h
    mov     dx, verdict_sus
    int     21h
    jmp     .done

.emulated:
    mov     ah, 09h
    mov     dx, verdict_emu
    int     21h

.done:
    ; Build fingerprint hash for server
    call    build_fingerprint

    mov     ah, 09h
    mov     dx, fp_header
    int     21h

    ; Print fingerprint hash
    mov     si, fingerprint_hash
    mov     cx, 32
.print_fp:
    lodsb
    call    print_hex_byte
    loop    .print_fp

    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Wait for key
    mov     ah, 09h
    mov     dx, press_key
    int     21h
    mov     ah, 01h
    int     21h

    mov     ax, 4C00h
    int     21h

;=======================================================================
; LAYER 1: BIOS ROM Signature Scan
; Searches F000:0000-FFFF for emulator signatures
; Returns: AL=0 if clean, AL=1+ if emulator detected
;=======================================================================
layer1_bios_scan:
    push    bx
    push    cx
    push    si
    push    di
    push    es

    mov     ax, 0F000h
    mov     es, ax

    ; Check for DOSBox
    mov     di, sig_dosbox
    call    scan_for_sig
    jc      .found_dosbox

    ; Check for QEMU
    mov     di, sig_qemu
    call    scan_for_sig
    jc      .found_qemu

    ; Check for VirtualBox
    mov     di, sig_vbox
    call    scan_for_sig
    jc      .found_vbox

    ; Check for VMware
    mov     di, sig_vmware
    call    scan_for_sig
    jc      .found_vmware

    ; Check for Bochs
    mov     di, sig_bochs
    call    scan_for_sig
    jc      .found_bochs

    ; Check for PCem
    mov     di, sig_pcem
    call    scan_for_sig
    jc      .found_pcem

    ; Check for 86Box
    mov     di, sig_86box
    call    scan_for_sig
    jc      .found_86box

    ; Check for SeaBIOS (QEMU/Proxmox default)
    mov     di, sig_seabios
    call    scan_for_sig
    jc      .found_seabios

    ; Check for OVMF (UEFI VM)
    mov     di, sig_ovmf
    call    scan_for_sig
    jc      .found_ovmf

    ; Check for Proxmox-specific
    mov     di, sig_proxmox
    call    scan_for_sig
    jc      .found_proxmox

    ; Check for KVM
    mov     di, sig_kvm
    call    scan_for_sig
    jc      .found_kvm

    ; No emulator found
    xor     al, al
    jmp     .done

.found_dosbox:
    mov     si, name_dosbox
    jmp     .set_detected
.found_qemu:
    mov     si, name_qemu
    jmp     .set_detected
.found_vbox:
    mov     si, name_vbox
    jmp     .set_detected
.found_vmware:
    mov     si, name_vmware
    jmp     .set_detected
.found_bochs:
    mov     si, name_bochs
    jmp     .set_detected
.found_pcem:
    mov     si, name_pcem
    jmp     .set_detected
.found_86box:
    mov     si, name_86box
    jmp     .set_detected
.found_seabios:
    mov     si, name_seabios
    jmp     .set_detected
.found_ovmf:
    mov     si, name_ovmf
    jmp     .set_detected
.found_proxmox:
    mov     si, name_proxmox
    jmp     .set_detected
.found_kvm:
    mov     si, name_kvm

.set_detected:
    ; Copy name to detected_emu
    mov     di, detected_emu
.copy_name:
    lodsb
    stosb
    cmp     al, 0
    jne     .copy_name
    mov     al, 1

.done:
    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    ret

; Scan BIOS for signature at DS:DI
; Returns CF set if found
scan_for_sig:
    push    cx
    push    si
    push    di

    xor     si, si
    mov     cx, 0FFF0h

.scan_loop:
    push    cx
    push    si
    push    di

    ; Get signature length
    push    di
    xor     cx, cx
.get_len:
    cmp     byte [di], 0
    je      .got_len
    inc     di
    inc     cx
    jmp     .get_len
.got_len:
    pop     di

    ; Compare
.cmp_loop:
    jcxz    .match
    mov     al, [es:si]
    cmp     al, [di]
    jne     .no_match
    inc     si
    inc     di
    dec     cx
    jmp     .cmp_loop

.no_match:
    pop     di
    pop     si
    pop     cx
    inc     si
    loop    .scan_loop
    clc
    jmp     .ret

.match:
    pop     di
    pop     si
    pop     cx
    stc

.ret:
    pop     di
    pop     si
    pop     cx
    ret

;=======================================================================
; LAYER 2: Timer Jitter Analysis
; Real hardware has variance, emulators are too uniform
; Returns: AL=0 if good jitter, AL=1 if too uniform
;          BX=variance value
;=======================================================================
layer2_timer_jitter:
    push    cx
    push    dx
    push    si
    push    di

    ; Collect 64 timer samples
    mov     cx, 64
    mov     di, timer_samples

.sample_loop:
    push    cx

    ; Read PIT channel 0
    cli
    xor     al, al
    out     43h, al         ; Latch counter
    in      al, 40h         ; Low byte
    mov     ah, al
    in      al, 40h         ; High byte
    xchg    al, ah
    sti

    stosw

    ; Small variable delay based on current sample
    mov     bx, [di-2]
    and     bx, 00FFh
    add     bx, 50
.delay:
    dec     bx
    jnz     .delay

    pop     cx
    loop    .sample_loop

    ; Calculate deltas between consecutive samples
    mov     si, timer_samples
    mov     di, timer_deltas
    mov     cx, 63

.delta_loop:
    lodsw
    mov     bx, ax
    mov     ax, [si]
    sub     ax, bx
    ; Handle wrap
    cmp     ax, 0
    jge     .no_wrap
    neg     ax
.no_wrap:
    stosw
    loop    .delta_loop

    ; Calculate variance of deltas
    ; First get mean
    mov     si, timer_deltas
    mov     cx, 63
    xor     dx, dx
    xor     bx, bx          ; Sum high
.sum_loop:
    lodsw
    add     dx, ax
    adc     bx, 0
    loop    .sum_loop

    ; Mean = sum / 63 (approximate with / 64)
    shr     bx, 1
    rcr     dx, 1
    shr     bx, 1
    rcr     dx, 1
    shr     bx, 1
    rcr     dx, 1
    shr     bx, 1
    rcr     dx, 1
    shr     bx, 1
    rcr     dx, 1
    shr     bx, 1
    rcr     dx, 1
    mov     [timer_mean], dx

    ; Calculate sum of squared differences from mean
    mov     si, timer_deltas
    mov     cx, 63
    xor     bx, bx          ; Variance accumulator
.var_loop:
    lodsw
    sub     ax, [timer_mean]
    ; Square it (approximate - just use absolute)
    cmp     ax, 0
    jge     .pos
    neg     ax
.pos:
    add     bx, ax
    loop    .var_loop

    ; Store variance
    mov     [jitter_variance], bx

    ; Threshold: real hardware has variance > 100
    ; Emulators often < 20
    cmp     bx, 50
    jb      .too_uniform

    xor     al, al          ; Good jitter
    jmp     .done

.too_uniform:
    mov     al, 1           ; Failed - too uniform

.done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    ret

;=======================================================================
; LAYER 3: I/O Port Timing
; Measures timing of port accesses - VMs have delays
; Returns: AL=0 if timing looks real, AL=1 if suspicious
;=======================================================================
layer3_io_timing:
    push    bx
    push    cx
    push    dx

    ; Time 1000 port reads
    mov     cx, 1000

    ; Get start time
    xor     ax, ax
    int     1Ah             ; CX:DX = tick count
    push    dx

.io_loop:
    in      al, 61h         ; System port - always accessible
    in      al, 61h
    in      al, 61h
    in      al, 61h
    loop    .io_loop

    ; Get end time
    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    mov     [io_timing], dx

    ; Check for suspicious patterns
    ; Real hardware: 1-3 ticks for 4000 IN instructions
    ; Emulators: often 0 or > 5 ticks

    cmp     dx, 0
    je      .suspicious     ; Too fast - emulator optimized away
    cmp     dx, 10
    ja      .suspicious     ; Too slow - VM overhead

    ; Also check for perfectly round numbers (emulator artifact)
    test    dx, 1
    jnz     .ok             ; Odd number is good
    mov     ax, dx
    and     ax, 0Fh
    jz      .suspicious     ; Multiple of 16 is suspicious

.ok:
    xor     al, al
    jmp     .done

.suspicious:
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;=======================================================================
; LAYER 4: Memory Timing Patterns
; Real memory has cache effects, emulators are uniform
; Returns: AL=0 if real, AL=1 if emulated
;=======================================================================
layer4_memory_timing:
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es

    ; Access memory in different patterns
    ; Pattern 1: Sequential (should be cached fast)
    mov     ax, ds
    mov     es, ax
    mov     di, test_buffer
    mov     cx, 256
    xor     ax, ax

    ; Get start
    push    cx
    xor     ax, ax
    int     1Ah
    push    dx

    pop     cx
.seq_write:
    stosw
    loop    .seq_write

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    mov     [mem_seq_time], dx

    ; Pattern 2: Random-ish (cache misses)
    mov     si, test_buffer
    mov     cx, 256
    mov     bx, 17          ; Step size (prime)

    xor     ax, ax
    int     1Ah
    push    dx

.random_read:
    mov     ax, [si]
    add     si, bx
    cmp     si, test_buffer + 512
    jb      .no_wrap_r
    sub     si, 512
.no_wrap_r:
    loop    .random_read

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    mov     [mem_rnd_time], dx

    ; Real hardware: random slower than sequential
    ; Emulators: often same speed
    mov     ax, [mem_rnd_time]
    mov     bx, [mem_seq_time]

    ; If sequential = random, suspicious
    cmp     ax, bx
    je      .suspicious
    ; If random < sequential, very suspicious
    cmp     ax, bx
    jb      .suspicious

    xor     al, al
    jmp     .done

.suspicious:
    mov     al, 1

.done:
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret

;=======================================================================
; LAYER 5: CPUID Hypervisor Detection
; Check for hypervisor bit and vendor strings
; Returns: AL=0 if no hypervisor, AL=1 if detected
;=======================================================================
layer5_cpuid_hypervisor:
    push    bx
    push    cx
    push    dx

    ; First check if CPUID supported (486+)
    pushf
    pop     ax
    mov     bx, ax
    xor     ax, 200000h     ; Flip ID bit
    push    ax
    popf
    pushf
    pop     ax
    cmp     ax, bx
    je      .no_cpuid       ; No CPUID = old CPU, pass

    ; Check CPUID leaf 1 for hypervisor bit
    mov     eax, 1
    cpuid
    test    ecx, 80000000h  ; Bit 31 = hypervisor present
    jnz     .hypervisor_found

    ; Also check leaf 0x40000000 for hypervisor vendor
    mov     eax, 40000000h
    cpuid
    cmp     eax, 40000000h
    jbe     .no_hypervisor

    ; Got hypervisor vendor - decode it
    mov     [hypervisor_vendor], ebx
    mov     [hypervisor_vendor+4], ecx
    mov     [hypervisor_vendor+8], edx

    ; Check known vendors
    cmp     ebx, 'KVMK'     ; "KVMKVMKVM"
    je      .found_kvm_hv
    cmp     ebx, 'Micr'     ; "Microsoft Hv"
    je      .found_hyperv
    cmp     ebx, 'VMwa'     ; "VMwareVMware"
    je      .found_vmware_hv
    cmp     ebx, 'VBox'     ; "VBoxVBoxVBox"
    je      .found_vbox_hv
    cmp     ebx, 'XenV'     ; "XenVMMXenVMM"
    je      .found_xen

    ; Unknown hypervisor
    mov     si, name_hypervisor
    jmp     .set_name

.found_kvm_hv:
    mov     si, name_kvm
    jmp     .set_name
.found_hyperv:
    mov     si, name_hyperv
    jmp     .set_name
.found_vmware_hv:
    mov     si, name_vmware
    jmp     .set_name
.found_vbox_hv:
    mov     si, name_vbox
    jmp     .set_name
.found_xen:
    mov     si, name_xen
    jmp     .set_name

.hypervisor_found:
    mov     si, name_hypervisor

.set_name:
    mov     di, hypervisor_name
.copy:
    lodsb
    stosb
    cmp     al, 0
    jne     .copy
    mov     al, 1
    jmp     .done

.no_cpuid:
.no_hypervisor:
    xor     al, al

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;=======================================================================
; LAYER 6: Hardware Interrupt Timing
; Real hardware has IRQ timing variance
; Returns: AL=0 if looks real, AL=1 if suspicious
;=======================================================================
layer6_interrupt_timing:
    push    bx
    push    cx
    push    dx

    ; Measure time between timer ticks
    mov     cx, 8
    mov     di, irq_samples

.sample_irq:
    push    cx

    ; Wait for tick
    xor     ax, ax
    int     1Ah
    mov     bx, dx

.wait_tick:
    xor     ax, ax
    int     1Ah
    cmp     dx, bx
    je      .wait_tick

    ; Record time of tick
    mov     [di], dx
    add     di, 2

    pop     cx
    loop    .sample_irq

    ; Calculate differences
    mov     si, irq_samples
    mov     cx, 7
    xor     bx, bx          ; Variance accumulator

.calc_diff:
    lodsw
    mov     dx, [si]
    sub     dx, ax
    ; Add to variance if not exactly 1
    cmp     dx, 1
    je      .exact
    inc     bx
.exact:
    loop    .calc_diff

    ; Real hardware: usually some variance (bx > 0)
    ; Perfect emulation: all exactly 1 tick apart (bx = 0)
    cmp     bx, 0
    je      .suspicious

    xor     al, al
    jmp     .done

.suspicious:
    ; All intervals exactly 1 tick - too perfect
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;=======================================================================
; LAYER 7: Entropy Quality Assessment
; Collect entropy from multiple sources and assess quality
; Returns: AL=0 if good entropy, AL=1 if poor
;          BX=entropy score (higher = better)
;=======================================================================
layer7_entropy_quality:
    push    cx
    push    dx
    push    si
    push    di

    xor     bx, bx          ; Entropy score

    ; Source 1: PIT timer low bits
    in      al, 40h
    mov     cl, al
    xor     ch, ch

    in      al, 40h
    xor     cl, al

    ; Count set bits
    mov     al, cl
.count1:
    test    al, al
    jz      .done1
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count1
.done1:

    ; Source 2: Keyboard controller status
    in      al, 64h
    xor     cl, al
    mov     al, cl
.count2:
    test    al, al
    jz      .done2
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count2
.done2:

    ; Source 3: RTC registers
    mov     al, 0           ; Seconds
    out     70h, al
    in      al, 71h
    xor     cl, al

    mov     al, 2           ; Minutes
    out     70h, al
    in      al, 71h
    xor     cl, al

    mov     al, 4           ; Hours
    out     70h, al
    in      al, 71h
    xor     cl, al

    ; Count bits
    mov     al, cl
.count3:
    test    al, al
    jz      .done3
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count3
.done3:

    ; Source 4: Memory content hash
    mov     si, 0400h       ; BIOS data area
    mov     cx, 64
    xor     al, al
.hash_mem:
    xor     al, [si]
    rol     al, 1
    inc     si
    loop    .hash_mem
    xor     cl, al

    ; Count bits
    mov     al, cl
.count4:
    test    al, al
    jz      .done4
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count4
.done4:

    ; BX now has bit count (entropy indicator)
    ; Real hardware: usually 10-20+
    ; Emulators: often < 8 (less entropy sources)

    mov     [entropy_score], bx

    cmp     bx, 8
    jb      .low_entropy

    xor     al, al
    jmp     .done

.low_entropy:
    mov     al, 1

.done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    ret

;=======================================================================
; Build fingerprint hash from all detection data
;=======================================================================
build_fingerprint:
    push    ax
    push    bx
    push    cx
    push    si
    push    di

    ; Initialize hash with seed
    mov     di, fingerprint_hash
    mov     cx, 32
    mov     al, 0A5h
.init:
    mov     [di], al
    xor     al, cl
    ror     al, 1
    inc     di
    loop    .init

    ; Mix in layer results
    mov     di, fingerprint_hash
    mov     al, [layer1_result]
    xor     [di], al
    inc     di

    mov     al, [layer2_result]
    xor     [di], al
    inc     di

    mov     ax, [jitter_variance]
    xor     [di], al
    inc     di
    xor     [di], ah
    inc     di

    mov     al, [layer3_result]
    xor     [di], al
    inc     di

    mov     ax, [io_timing]
    xor     [di], al
    inc     di
    xor     [di], ah
    inc     di

    mov     al, [layer4_result]
    xor     [di], al
    inc     di

    mov     al, [layer5_result]
    xor     [di], al
    inc     di

    mov     al, [layer6_result]
    xor     [di], al
    inc     di

    mov     al, [layer7_result]
    xor     [di], al
    inc     di

    mov     ax, [entropy_score]
    xor     [di], al
    inc     di
    xor     [di], ah
    inc     di

    ; Add detected emulator name
    mov     si, detected_emu
    mov     cx, 16
.mix_name:
    lodsb
    cmp     di, fingerprint_hash + 32
    jb      .no_wrap
    mov     di, fingerprint_hash
.no_wrap:
    xor     [di], al
    rol     byte [di], 3
    inc     di
    loop    .mix_name

    ; Final mixing rounds
    mov     cx, 3
.mix_round:
    mov     si, fingerprint_hash
    mov     di, fingerprint_hash
    push    cx
    mov     cx, 32
.mix_byte:
    lodsb
    add     al, cl
    ror     al, 1
    xor     al, 5Ah
    stosb
    loop    .mix_byte
    pop     cx
    loop    .mix_round

    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

;=======================================================================
; Utility: Print null-terminated string at SI
;=======================================================================
print_string:
    push    ax
    push    si
.loop:
    lodsb
    cmp     al, 0
    je      .done
    mov     dl, al
    mov     ah, 02h
    int     21h
    jmp     .loop
.done:
    mov     ah, 09h
    mov     dx, newline
    int     21h
    pop     si
    pop     ax
    ret

;=======================================================================
; Utility: Print AL as hex byte
;=======================================================================
print_hex_byte:
    push    ax
    push    bx

    mov     bx, hex_chars
    mov     ah, al
    shr     al, 4
    xlat
    mov     dl, al
    mov     ah, 02h
    int     21h

    mov     al, byte [esp+3]
    and     al, 0Fh
    mov     bx, hex_chars
    xlat
    mov     dl, al
    mov     ah, 02h
    int     21h

    pop     bx
    pop     ax
    ret

;=======================================================================
; Utility: Print AX as decimal
;=======================================================================
print_decimal:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     bx, 10
    xor     cx, cx

.divide:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .divide

.print:
    pop     dx
    add     dl, '0'
    mov     ah, 02h
    int     21h
    loop    .print

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;=======================================================================
; Data section
;=======================================================================
section .data

banner:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  RUSTCHAIN ANTI-CHEAT MODULE v1.0', 13, 10
    db '  7-Layer Emulation Detection for RIP-PoA', 13, 10
    db ' ================================================================', 13, 10
    db 13, 10
    db '  Checking for emulation/virtualization...', 13, 10
    db 13, 10, '$'

layer1_msg: db '  [1/7] BIOS ROM Signature Scan........... $'
layer2_msg: db '  [2/7] Timer Jitter Analysis............. $'
layer3_msg: db '  [3/7] I/O Port Timing................... $'
layer4_msg: db '  [4/7] Memory Timing Patterns............ $'
layer5_msg: db '  [5/7] CPUID Hypervisor Detection........ $'
layer6_msg: db '  [6/7] Hardware Interrupt Timing......... $'
layer7_msg: db '  [7/7] Entropy Quality Assessment........ $'

pass_msg:   db 'PASS', 13, 10, '$'
fail_msg:   db 'FAIL - $'

jitter_low_msg:     db 'Timer jitter too uniform', 13, 10, '$'
timing_uniform_msg: db 'I/O timing suspicious', 13, 10, '$'
entropy_low_msg:    db 'Entropy quality poor', 13, 10, '$'

summary_header:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  DETECTION SUMMARY', 13, 10
    db ' ================================================================', 13, 10, '$'

layers_lbl:     db '  Layers Passed: $'
of_7_msg:       db '/7', 13, 10, '$'
score_lbl:      db '  Authenticity Score: $'
percent_msg:    db '%', 13, 10, 13, 10, '$'

verdict_real:
    db '  VERDICT: REAL HARDWARE DETECTED', 13, 10
    db '  Full antiquity multiplier will be applied!', 13, 10, '$'

verdict_sus:
    db '  VERDICT: SUSPICIOUS - PARTIAL DETECTION', 13, 10
    db '  Reduced antiquity multiplier will be applied.', 13, 10, '$'

verdict_emu:
    db '  VERDICT: EMULATION DETECTED', 13, 10
    db '  Minimal rewards (1e-9 weight) will be applied.', 13, 10
    db '  Run on REAL vintage hardware for full rewards!', 13, 10, '$'

fp_header:
    db 13, 10, '  Hardware Fingerprint Hash:', 13, 10, '  $'

press_key:      db 13, 10, '  Press any key to exit...', 13, 10, '$'
newline:        db 13, 10, '$'
hex_chars:      db '0123456789ABCDEF'

; Emulator signature strings
sig_dosbox:     db 'DOSBox', 0
sig_qemu:       db 'QEMU', 0
sig_vbox:       db 'VBOX', 0
sig_vmware:     db 'VMware', 0
sig_bochs:      db 'BOCHS', 0
sig_pcem:       db 'PCem', 0
sig_86box:      db '86Box', 0
sig_seabios:    db 'SeaBIOS', 0
sig_ovmf:       db 'OVMF', 0
sig_proxmox:    db 'Proxmox', 0
sig_kvm:        db 'KVMKVMKVM', 0

; Display names
name_dosbox:    db 'DOSBox Emulator', 0
name_qemu:      db 'QEMU/KVM', 0
name_vbox:      db 'VirtualBox', 0
name_vmware:    db 'VMware', 0
name_bochs:     db 'Bochs Emulator', 0
name_pcem:      db 'PCem Emulator', 0
name_86box:     db '86Box Emulator', 0
name_seabios:   db 'SeaBIOS (QEMU/Proxmox)', 0
name_ovmf:      db 'OVMF UEFI (VM)', 0
name_proxmox:   db 'Proxmox VE', 0
name_kvm:       db 'Linux KVM', 0
name_hyperv:    db 'Hyper-V', 0
name_xen:       db 'Xen Hypervisor', 0
name_hypervisor: db 'Unknown Hypervisor', 0

section .bss

; Detection results
layer1_result:      resb 1
layer2_result:      resb 1
layer3_result:      resb 1
layer4_result:      resb 1
layer5_result:      resb 1
layer6_result:      resb 1
layer7_result:      resb 1
layers_passed:      resb 1
total_score:        resb 1

detected_emu:       resb 32
hypervisor_name:    resb 32
hypervisor_vendor:  resb 16

; Timing data
timer_samples:      resw 64
timer_deltas:       resw 64
timer_mean:         resw 1
jitter_variance:    resw 1
io_timing:          resw 1
mem_seq_time:       resw 1
mem_rnd_time:       resw 1
irq_samples:        resw 8
entropy_score:      resw 1

; Test buffers
test_buffer:        resb 512

; Final fingerprint
fingerprint_hash:   resb 32
