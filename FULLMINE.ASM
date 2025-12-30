; RustChain Full Miner - Integrated with 7-Layer Anti-Cheat
; Creates attestation file (ATTEST.TXT) with hardware fingerprint
; Server requires ALL 7 layers to pass for full antiquity bonus!
;
; Assembles with: nasm -f bin -o FULLMINE.COM FULLMINE.asm

org 100h

section .text

start:
    mov     ax, 0003h
    int     10h

    mov     ah, 09h
    mov     dx, banner
    int     21h

    ; Initialize
    mov     byte [layers_passed], 0
    mov     byte [emulator_detected], 0

    ; === LAYER 1: BIOS ROM Signature Scan ===
    mov     ah, 09h
    mov     dx, layer1_msg
    int     21h
    call    layer1_bios_scan
    mov     [layer1_result], al
    call    show_result

    ; === LAYER 2: Timer Jitter ===
    mov     ah, 09h
    mov     dx, layer2_msg
    int     21h
    call    layer2_timer_jitter
    mov     [layer2_result], al
    call    show_result

    ; === LAYER 3: I/O Port Timing ===
    mov     ah, 09h
    mov     dx, layer3_msg
    int     21h
    call    layer3_io_timing
    mov     [layer3_result], al
    call    show_result

    ; === LAYER 4: Memory Timing ===
    mov     ah, 09h
    mov     dx, layer4_msg
    int     21h
    call    layer4_mem_timing
    mov     [layer4_result], al
    call    show_result

    ; === LAYER 5: CPUID Hypervisor ===
    mov     ah, 09h
    mov     dx, layer5_msg
    int     21h
    call    layer5_cpuid
    mov     [layer5_result], al
    call    show_result

    ; === LAYER 6: Interrupt Timing ===
    mov     ah, 09h
    mov     dx, layer6_msg
    int     21h
    call    layer6_irq_timing
    mov     [layer6_result], al
    call    show_result

    ; === LAYER 7: Entropy Quality ===
    mov     ah, 09h
    mov     dx, layer7_msg
    int     21h
    call    layer7_entropy
    mov     [layer7_result], al
    call    show_result

    ; Show summary
    mov     ah, 09h
    mov     dx, summary_hdr
    int     21h

    mov     al, [layers_passed]
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     ah, 09h
    mov     dx, of_7
    int     21h

    ; Verdict
    cmp     byte [layers_passed], 7
    je      .real_hw
    cmp     byte [layers_passed], 5
    jae     .suspicious
    jmp     .emulated

.real_hw:
    mov     ah, 09h
    mov     dx, verdict_real
    int     21h
    jmp     .gen_wallet

.suspicious:
    mov     ah, 09h
    mov     dx, verdict_sus
    int     21h
    jmp     .gen_wallet

.emulated:
    mov     ah, 09h
    mov     dx, verdict_emu
    int     21h

.gen_wallet:
    ; Generate wallet
    mov     ah, 09h
    mov     dx, gen_msg
    int     21h
    call    generate_wallet

    ; Show wallet
    mov     ah, 09h
    mov     dx, wallet_lbl
    int     21h
    mov     ah, 09h
    mov     dx, wallet_addr
    int     21h
    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Create attestation file
    call    write_attestation

    mov     ah, 09h
    mov     dx, saved_msg
    int     21h

    ; Wait for key
    mov     ah, 09h
    mov     dx, press_key
    int     21h
    mov     ah, 01h
    int     21h

    mov     ax, 4C00h
    int     21h

;---------------------------------------
; Show pass/fail result (AL = result)
;---------------------------------------
show_result:
    cmp     al, 0
    jne     .failed
    inc     byte [layers_passed]
    mov     ah, 09h
    mov     dx, pass_msg
    int     21h
    ret
.failed:
    mov     ah, 09h
    mov     dx, fail_msg
    int     21h
    ret

;---------------------------------------
; LAYER 1: BIOS ROM Scan
;---------------------------------------
layer1_bios_scan:
    push    bx
    push    cx
    push    si
    push    di
    push    es

    mov     ax, 0F000h
    mov     es, ax
    xor     di, di
    mov     cx, 0FFF0h

    ; Scan for emulator signatures
.scan:
    ; DOSBox
    cmp     word [es:di], 'DO'
    jne     .not_dosbox
    cmp     word [es:di+2], 'SB'
    je      .found_emu
.not_dosbox:
    ; QEMU
    cmp     dword [es:di], 'QEMU'
    je      .found_emu
    ; VBox
    cmp     dword [es:di], 'VBOX'
    je      .found_emu
    ; VMware
    cmp     dword [es:di], 'VMwa'
    je      .found_emu
    ; SeaBIOS
    cmp     dword [es:di], 'SeaB'
    je      .found_emu
    ; Bochs
    cmp     dword [es:di], 'BOCH'
    je      .found_emu

    inc     di
    loop    .scan

    xor     al, al
    jmp     .done

.found_emu:
    mov     byte [emulator_detected], 1
    mov     al, 1

.done:
    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 2: Timer Jitter
;---------------------------------------
layer2_timer_jitter:
    push    bx
    push    cx
    push    dx

    ; Collect 32 samples
    mov     cx, 32
    mov     di, samples
    xor     bx, bx          ; Min
    mov     dx, 0FFFFh      ; Max

.sample:
    push    cx
    cli
    xor     al, al
    out     43h, al
    in      al, 40h
    mov     ah, al
    in      al, 40h
    xchg    al, ah
    sti

    ; Track min/max
    cmp     ax, bx
    jbe     .not_new_max
    mov     bx, ax
.not_new_max:
    cmp     ax, dx
    jae     .not_new_min
    mov     dx, ax
.not_new_min:

    ; Small delay
    push    cx
    mov     cx, 100
.delay:
    loop    .delay
    pop     cx

    pop     cx
    loop    .sample

    ; Calculate range
    sub     bx, dx
    mov     [jitter_range], bx

    ; Real HW has variance > 20
    cmp     bx, 20
    jb      .fail
    xor     al, al
    jmp     .done
.fail:
    mov     al, 1
.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 3: I/O Port Timing
;---------------------------------------
layer3_io_timing:
    push    bx
    push    cx
    push    dx

    ; Time 500 port reads
    xor     ax, ax
    int     1Ah
    push    dx

    mov     cx, 500
.io_loop:
    in      al, 61h
    in      al, 61h
    loop    .io_loop

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx

    ; 0 ticks = emulator
    cmp     dx, 0
    je      .fail
    cmp     dx, 10
    ja      .fail

    xor     al, al
    jmp     .done
.fail:
    mov     al, 1
.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 4: Memory Timing
;---------------------------------------
layer4_mem_timing:
    push    bx
    push    cx
    push    dx
    push    es

    mov     ax, ds
    mov     es, ax

    ; Sequential access
    xor     ax, ax
    int     1Ah
    push    dx

    mov     di, membuf
    mov     cx, 256
    xor     ax, ax
.seq:
    stosw
    loop    .seq

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    mov     [seq_time], dx

    ; Random-ish access
    xor     ax, ax
    int     1Ah
    push    dx

    mov     si, membuf
    mov     cx, 256
.rnd:
    lodsw
    add     si, 17
    cmp     si, membuf+512
    jb      .no_wrap
    sub     si, 512
.no_wrap:
    loop    .rnd

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    mov     [rnd_time], dx

    ; Random should >= sequential
    mov     ax, [rnd_time]
    cmp     ax, [seq_time]
    jb      .fail

    xor     al, al
    jmp     .done
.fail:
    mov     al, 1
.done:
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 5: CPUID Hypervisor
;---------------------------------------
layer5_cpuid:
    push    bx
    push    cx
    push    dx

    ; Check CPUID support
    pushf
    pop     ax
    mov     bx, ax
    xor     ax, 200000h
    push    ax
    popf
    pushf
    pop     ax
    cmp     ax, bx
    je      .no_cpuid

    ; Check hypervisor bit
    mov     eax, 1
    cpuid
    test    ecx, 80000000h
    jnz     .hypervisor

    ; Check for hypervisor leaf
    mov     eax, 40000000h
    cpuid
    cmp     eax, 40000000h
    ja      .hypervisor

.no_cpuid:
    xor     al, al
    jmp     .done

.hypervisor:
    mov     byte [emulator_detected], 1
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 6: IRQ Timing
;---------------------------------------
layer6_irq_timing:
    push    bx
    push    cx
    push    dx

    ; Measure 4 tick intervals
    mov     cx, 4
    xor     bx, bx          ; Variance

.tick_loop:
    push    cx
    xor     ax, ax
    int     1Ah
    mov     si, dx
.wait:
    xor     ax, ax
    int     1Ah
    cmp     dx, si
    je      .wait

    ; Check if exactly 1 tick
    sub     dx, si
    cmp     dx, 1
    je      .exact
    inc     bx
.exact:
    pop     cx
    loop    .tick_loop

    ; All exact = suspicious
    cmp     bx, 0
    je      .fail
    xor     al, al
    jmp     .done
.fail:
    mov     al, 1
.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; LAYER 7: Entropy Quality
;---------------------------------------
layer7_entropy:
    push    bx
    push    cx
    push    dx

    xor     bx, bx          ; Bit count

    ; PIT
    in      al, 40h
    mov     cl, al
    in      al, 40h
    xor     cl, al

    ; Count bits
    mov     al, cl
.count1:
    test    al, al
    jz      .src2
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count1

.src2:
    ; RTC
    mov     al, 0
    out     70h, al
    in      al, 71h
    xor     cl, al

    mov     al, cl
.count2:
    test    al, al
    jz      .check
    mov     dl, al
    and     dl, 1
    add     bl, dl
    shr     al, 1
    jmp     .count2

.check:
    mov     [entropy_score], bx

    ; Need at least 4 bits
    cmp     bx, 4
    jb      .fail
    xor     al, al
    jmp     .done
.fail:
    mov     al, 1
.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; Generate wallet from entropy
;---------------------------------------
generate_wallet:
    push    ax
    push    bx
    push    cx
    push    si
    push    di
    push    es

    ; Collect entropy
    mov     ax, 0F000h
    mov     es, ax
    mov     si, 0FFF5h
    mov     di, entropy
    mov     cx, 8
.copy_bios:
    mov     al, [es:si]
    mov     [di], al
    inc     si
    inc     di
    loop    .copy_bios

    ; Timer ticks
    xor     ax, ax
    int     1Ah
    mov     [entropy+8], dx
    mov     [entropy+10], cx

    ; RTC
    mov     al, 0
    out     70h, al
    in      al, 71h
    mov     [entropy+12], al
    mov     al, 2
    out     70h, al
    in      al, 71h
    mov     [entropy+13], al

    ; Hash entropy
    mov     di, hash_out
    mov     cx, 20
    mov     al, 5Ah
.init_hash:
    mov     [di], al
    xor     al, cl
    add     al, 17h
    inc     di
    loop    .init_hash

    mov     si, entropy
    mov     di, hash_out
    mov     cx, 14
.xor_loop:
    lodsb
    xor     [di], al
    rol     byte [di], 3
    inc     di
    loop    .xor_loop

    ; Build wallet string
    mov     di, wallet_addr
    mov     byte [di], 'R'
    inc     di
    mov     byte [di], 'T'
    inc     di
    mov     byte [di], 'C'
    inc     di

    mov     si, hash_out
    mov     cx, 20
.hex_loop:
    lodsb
    call    byte_to_hex
    loop    .hex_loop

    mov     byte [di], '$'

    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Byte to hex (AL -> [DI])
;---------------------------------------
byte_to_hex:
    push    ax
    push    bx
    mov     bx, hexchars
    mov     ah, al
    shr     al, 4
    xlat
    mov     [di], al
    inc     di
    mov     al, ah
    and     al, 0Fh
    xlat
    mov     [di], al
    inc     di
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Write attestation file
;---------------------------------------
write_attestation:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Create file
    mov     ah, 3Ch
    mov     cx, 0
    mov     dx, attest_file
    int     21h
    jc      .error
    mov     bx, ax

    ; Write header
    mov     ah, 40h
    mov     cx, attest_hdr_len
    mov     dx, attest_hdr
    int     21h

    ; Write wallet
    mov     ah, 40h
    mov     cx, 43
    mov     dx, wallet_addr
    int     21h

    ; Write newline
    mov     ah, 40h
    mov     cx, 2
    mov     dx, crlf
    int     21h

    ; Write layers passed
    mov     ah, 40h
    mov     cx, layers_line_len
    mov     dx, layers_line
    int     21h

    mov     al, [layers_passed]
    add     al, '0'
    mov     [numbuf], al
    mov     ah, 40h
    mov     cx, 1
    mov     dx, numbuf
    int     21h

    ; Write /7
    mov     ah, 40h
    mov     cx, 4
    mov     dx, slash7
    int     21h

    ; Write emulator status
    mov     ah, 40h
    mov     cx, emu_line_len
    mov     dx, emu_line
    int     21h

    cmp     byte [emulator_detected], 0
    je      .no_emu
    mov     ah, 40h
    mov     cx, 4
    mov     dx, yes_str
    int     21h
    jmp     .close
.no_emu:
    mov     ah, 40h
    mov     cx, 2
    mov     dx, no_str
    int     21h

.close:
    mov     ah, 40h
    mov     cx, 2
    mov     dx, crlf
    int     21h

    mov     ah, 3Eh
    int     21h

.error:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Data
;---------------------------------------
section .data

banner:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  RUSTCHAIN FULL MINER v1.0 - Proof of Antiquity (RIP-PoA)', 13, 10
    db ' ================================================================', 13, 10
    db 13, 10
    db '  Running 7-layer anti-cheat detection...', 13, 10
    db 13, 10, '$'

layer1_msg: db '  [1/7] BIOS Signature Scan.......... $'
layer2_msg: db '  [2/7] Timer Jitter Analysis........ $'
layer3_msg: db '  [3/7] I/O Port Timing.............. $'
layer4_msg: db '  [4/7] Memory Timing................ $'
layer5_msg: db '  [5/7] CPUID Hypervisor............. $'
layer6_msg: db '  [6/7] IRQ Timing................... $'
layer7_msg: db '  [7/7] Entropy Quality.............. $'

pass_msg:   db 'PASS', 13, 10, '$'
fail_msg:   db 'FAIL', 13, 10, '$'

summary_hdr:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  SUMMARY: Layers passed: $'

of_7:       db '/7', 13, 10, '$'

verdict_real:
    db 13, 10, '  VERDICT: REAL HARDWARE - Full antiquity bonus!', 13, 10, '$'

verdict_sus:
    db 13, 10, '  VERDICT: SUSPICIOUS - Reduced bonus', 13, 10, '$'

verdict_emu:
    db 13, 10, '  VERDICT: EMULATED - Minimal rewards (1e-9)', 13, 10, '$'

gen_msg:
    db 13, 10, '  Generating wallet from hardware entropy...', 13, 10, '$'

wallet_lbl: db '  Wallet: $'
saved_msg:  db 13, 10, '  Attestation saved to ATTEST.TXT', 13, 10, '$'
press_key:  db 13, 10, '  Press any key to exit...', 13, 10, '$'
newline:    db 13, 10, '$'
crlf:       db 13, 10

hexchars:   db '0123456789abcdef'

attest_file: db 'ATTEST.TXT', 0
attest_hdr: db 'RUSTCHAIN_ATTESTATION_V1', 13, 10, 'WALLET='
attest_hdr_len equ $ - attest_hdr
layers_line: db 'LAYERS_PASSED='
layers_line_len equ $ - layers_line
slash7:     db '/7', 13, 10
emu_line:   db 'EMULATOR_DETECTED='
emu_line_len equ $ - emu_line
yes_str:    db 'YES', 13, 10
no_str:     db 'NO'

section .bss

layers_passed:      resb 1
emulator_detected:  resb 1
layer1_result:      resb 1
layer2_result:      resb 1
layer3_result:      resb 1
layer4_result:      resb 1
layer5_result:      resb 1
layer6_result:      resb 1
layer7_result:      resb 1

jitter_range:       resw 1
seq_time:           resw 1
rnd_time:           resw 1
entropy_score:      resw 1

samples:            resw 32
membuf:             resb 512
entropy:            resb 16
hash_out:           resb 20
wallet_addr:        resb 64
numbuf:             resb 4
