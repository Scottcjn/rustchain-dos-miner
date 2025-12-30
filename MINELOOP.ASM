; RustChain Continuous Miner - Loops and attests
; With STRICT entropy checking that fails on emulators
;
; Assembles with: nasm -f bin -o MINELOOP.COM MINELOOP.asm

org 100h

section .text

start:
    mov     ax, 0003h
    int     10h

    mov     ah, 09h
    mov     dx, banner
    int     21h

    ; Initial hardware check
    call    full_detection

    ; Show initial result
    call    show_status

    ; Check emulation status (but KEEP RUNNING either way!)
    cmp     byte [layers_passed], 5
    jae     .real_hardware
    jmp     .emulator_detected

.real_hardware:
    jmp     .mine_loop

.emulator_detected:

    ; Emulator detected - show warning but CONTINUE MINING
    mov     ah, 09h
    mov     dx, emu_warning
    int     21h

    ; Small delay to let keyboard settle
    mov     cx, 0FFFFh
.settle:
    loop    .settle

    ; Main mining loop (runs for BOTH real and emulated hardware)
.mine_loop:
    ; Show mining animation frame
    call    show_mining_frame

    ; Increment block counter
    inc     word [blocks_mined]

    ; Every 10 "blocks", do attestation
    mov     ax, [blocks_mined]
    mov     bl, 10
    div     bl
    cmp     ah, 0
    jne     .no_attest

    ; Do attestation
    call    do_attestation
    call    show_attest_status

.no_attest:
    ; Delay (~1 second)
    call    delay_1sec

    ; Check for ESC key
    mov     ah, 01h
    int     16h
    jz      .mine_loop
    mov     ah, 00h
    int     16h
    cmp     al, 27          ; ESC
    je      .exit_mining
    jmp     .mine_loop

.exit_mining:
    mov     ah, 09h
    mov     dx, exit_msg
    int     21h

.exit:
    mov     ax, 4C00h
    int     21h

;---------------------------------------
; Full 7-layer detection
;---------------------------------------
full_detection:
    push    ax

    mov     byte [layers_passed], 0
    mov     byte [emulator_detected], 0

    ; Layer 1: BIOS scan
    call    layer1_bios
    mov     [layer_results], al

    ; Layer 2: Timer jitter
    call    layer2_jitter
    mov     [layer_results+1], al

    ; Layer 3: I/O timing
    call    layer3_io
    mov     [layer_results+2], al

    ; Layer 4: Memory timing
    call    layer4_mem
    mov     [layer_results+3], al

    ; Layer 5: CPUID hypervisor
    call    layer5_cpuid
    mov     [layer_results+4], al

    ; Layer 6: IRQ timing
    call    layer6_irq
    mov     [layer_results+5], al

    ; Layer 7: STRICT entropy check
    call    layer7_entropy_strict
    mov     [layer_results+6], al

    pop     ax
    ret

;---------------------------------------
; Layer 1: BIOS Signature
;---------------------------------------
layer1_bios:
    push    es
    push    di
    push    cx

    mov     ax, 0F000h
    mov     es, ax
    xor     di, di
    mov     cx, 0FFF0h

.scan:
    ; DOSBox
    cmp     word [es:di], 'DO'
    jne     .not_dos
    cmp     word [es:di+2], 'SB'
    je      .found
.not_dos:
    ; QEMU
    cmp     dword [es:di], 'QEMU'
    je      .found
    ; SeaBIOS (Proxmox/QEMU default)
    cmp     dword [es:di], 'SeaB'
    je      .found
    ; VBox
    cmp     dword [es:di], 'VBOX'
    je      .found
    ; VMware
    cmp     dword [es:di], 'VMwa'
    je      .found
    ; Bochs
    cmp     dword [es:di], 'BOCH'
    je      .found

    inc     di
    loop    .scan

    inc     byte [layers_passed]
    xor     al, al
    jmp     .done

.found:
    mov     byte [emulator_detected], 1
    mov     al, 1

.done:
    pop     cx
    pop     di
    pop     es
    ret

;---------------------------------------
; Layer 2: Timer Jitter (STRICT)
;---------------------------------------
layer2_jitter:
    push    bx
    push    cx
    push    dx

    mov     cx, 64
    xor     bx, bx          ; Variance accumulator
    xor     dx, dx          ; Previous sample

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

    ; Calculate delta from previous
    cmp     dx, 0
    je      .first
    mov     cx, ax
    sub     cx, dx
    ; Absolute value
    cmp     cx, 0
    jge     .pos
    neg     cx
.pos:
    add     bx, cx
.first:
    mov     dx, ax

    ; Variable delay based on sample
    push    bx
    and     bx, 0FFh
    add     bx, 50
.delay:
    dec     bx
    jnz     .delay
    pop     bx

    pop     cx
    loop    .sample

    ; Store variance
    mov     [jitter_var], bx

    ; STRICT: Real hardware variance > 100
    ; Emulators typically < 50
    cmp     bx, 80
    jb      .fail

    inc     byte [layers_passed]
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
; Layer 3: I/O Port Timing
;---------------------------------------
layer3_io:
    push    bx
    push    cx
    push    dx

    xor     ax, ax
    int     1Ah
    push    dx

    mov     cx, 1000
.io:
    in      al, 61h
    in      al, 61h
    loop    .io

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx

    ; 0 = too fast (optimized away)
    ; >8 = too slow (VM overhead)
    cmp     dx, 0
    je      .fail
    cmp     dx, 8
    ja      .fail

    inc     byte [layers_passed]
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
; Layer 4: Memory Timing
;---------------------------------------
layer4_mem:
    push    bx
    push    cx
    push    dx
    push    es

    mov     ax, ds
    mov     es, ax

    ; Sequential
    xor     ax, ax
    int     1Ah
    push    dx

    mov     di, membuf
    mov     cx, 256
.seq:
    stosw
    loop    .seq

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx
    push    dx

    ; Random
    xor     ax, ax
    int     1Ah
    push    dx

    mov     si, membuf
    mov     cx, 256
.rnd:
    lodsw
    add     si, 31
    cmp     si, membuf+512
    jb      .ok
    sub     si, 512
.ok:
    loop    .rnd

    xor     ax, ax
    int     1Ah
    pop     bx
    sub     dx, bx

    pop     cx              ; Sequential time
    ; Random should be >= sequential on real HW
    cmp     dx, cx
    jb      .fail

    inc     byte [layers_passed]
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
; Layer 5: CPUID Hypervisor
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
    je      .no_cpuid       ; Old CPU = pass

    ; Check hypervisor bit
    mov     eax, 1
    cpuid
    test    ecx, 80000000h
    jnz     .found

    ; Check hypervisor leaf
    mov     eax, 40000000h
    cpuid
    cmp     eax, 40000000h
    ja      .found

.no_cpuid:
    inc     byte [layers_passed]
    xor     al, al
    jmp     .done

.found:
    mov     byte [emulator_detected], 1
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

;---------------------------------------
; Layer 6: IRQ Timing
;---------------------------------------
layer6_irq:
    push    bx
    push    cx
    push    dx

    mov     cx, 8
    xor     bx, bx

.tick:
    push    cx
    xor     ax, ax
    int     1Ah
    mov     si, dx
.wait:
    xor     ax, ax
    int     1Ah
    cmp     dx, si
    je      .wait

    sub     dx, si
    cmp     dx, 1
    je      .exact
    inc     bx
.exact:
    pop     cx
    loop    .tick

    ; All exactly 1 = too perfect = emulated
    cmp     bx, 0
    je      .fail

    inc     byte [layers_passed]
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
; Layer 7: STRICT Entropy Check
; Emulators have poor/synthetic entropy!
;---------------------------------------
layer7_entropy_strict:
    push    bx
    push    cx
    push    dx

    ; Collect entropy from MULTIPLE sources
    ; Real hardware: rich, varied entropy
    ; Emulators: synthetic, repetitive

    xor     bx, bx          ; Entropy score

    ; === Source 1: PIT rapid sampling ===
    ; Real HW: LSBs vary wildly
    ; Emulators: often constant or patterned
    mov     cx, 16
    xor     dl, dl          ; XOR accumulator
.pit_sample:
    in      al, 40h
    xor     dl, al
    ; Tiny delay
    push    cx
    mov     cx, 10
.pd:
    loop    .pd
    pop     cx
    loop    .pit_sample

    ; Count unique bits
    mov     al, dl
    call    count_bits
    add     bx, ax

    ; === Source 2: Keyboard controller ===
    in      al, 64h
    mov     dl, al
    in      al, 60h
    xor     dl, al
    mov     al, dl
    call    count_bits
    add     bx, ax

    ; === Source 3: RTC with timing ===
    mov     al, 0
    out     70h, al
    in      al, 71h
    mov     dl, al

    ; Read again after tiny delay
    mov     cx, 50
.rtc_d:
    loop    .rtc_d

    mov     al, 0
    out     70h, al
    in      al, 71h
    xor     dl, al          ; Should differ on real HW
    mov     al, dl
    call    count_bits
    add     bx, ax

    ; === Source 4: Port 61h status ===
    in      al, 61h
    mov     dl, al
    mov     cx, 100
.p61:
    loop    .p61
    in      al, 61h
    xor     dl, al
    mov     al, dl
    call    count_bits
    add     bx, ax

    ; === Source 5: Memory content variance ===
    mov     si, 0400h       ; BIOS data area
    xor     dl, dl
    mov     cx, 32
.mem_ent:
    lodsb
    xor     dl, al
    rol     dl, 1
    loop    .mem_ent
    mov     al, dl
    call    count_bits
    add     bx, ax

    ; Store entropy score
    mov     [entropy_score], bx

    ; STRICT threshold:
    ; Real hardware: typically 15-30+ bits of entropy
    ; Emulators: typically < 10 (synthetic sources)
    cmp     bx, 12
    jb      .fail

    inc     byte [layers_passed]
    xor     al, al
    jmp     .done

.fail:
    mov     al, 1

.done:
    pop     dx
    pop     cx
    pop     bx
    ret

; Count set bits in AL, return in AX
count_bits:
    push    cx
    xor     ah, ah
    xor     cx, cx
.cnt:
    test    al, al
    jz      .cnt_done
    mov     cl, al
    and     cl, 1
    add     ah, cl
    shr     al, 1
    jmp     .cnt
.cnt_done:
    mov     al, ah
    xor     ah, ah
    pop     cx
    ret

;---------------------------------------
; Show detection status
;---------------------------------------
show_status:
    push    ax

    mov     ah, 09h
    mov     dx, status_hdr
    int     21h

    ; Show each layer
    mov     cx, 7
    mov     si, layer_results
    mov     di, layer_names
.show_layer:
    push    cx

    ; Layer name
    mov     ah, 09h
    mov     dx, di
    int     21h

    ; Result
    lodsb
    cmp     al, 0
    jne     .layer_fail
    mov     ah, 09h
    mov     dx, pass_str
    int     21h
    jmp     .next_layer
.layer_fail:
    mov     ah, 09h
    mov     dx, fail_str
    int     21h

.next_layer:
    add     di, 32          ; Next layer name
    pop     cx
    loop    .show_layer

    ; Summary
    mov     ah, 09h
    mov     dx, sum_lbl
    int     21h

    mov     al, [layers_passed]
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h

    mov     ah, 09h
    mov     dx, of7_str
    int     21h

    ; Entropy score
    mov     ah, 09h
    mov     dx, ent_lbl
    int     21h
    mov     ax, [entropy_score]
    call    print_dec
    mov     ah, 09h
    mov     dx, bits_str
    int     21h

    pop     ax
    ret

;---------------------------------------
; Show mining animation frame
;---------------------------------------
show_mining_frame:
    push    ax
    push    bx
    push    dx

    ; Position cursor
    mov     ah, 02h
    mov     bh, 0
    mov     dh, 20          ; Row
    mov     dl, 5           ; Column
    int     10h

    ; Get frame (0-3)
    mov     ax, [blocks_mined]
    and     ax, 3

    ; Show frame
    cmp     al, 0
    je      .f0
    cmp     al, 1
    je      .f1
    cmp     al, 2
    je      .f2
    jmp     .f3

.f0:
    mov     dx, frame0
    jmp     .show
.f1:
    mov     dx, frame1
    jmp     .show
.f2:
    mov     dx, frame2
    jmp     .show
.f3:
    mov     dx, frame3

.show:
    mov     ah, 09h
    int     21h

    ; Show block count
    mov     ah, 02h
    mov     bh, 0
    mov     dh, 19
    mov     dl, 40
    int     10h

    mov     ah, 09h
    mov     dx, block_lbl
    int     21h

    mov     ax, [blocks_mined]
    call    print_dec

    pop     dx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Do attestation (save to file)
;---------------------------------------
do_attestation:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Load or generate wallet (PERSISTENT)
    cmp     byte [wallet_gen], 0
    jne     .have_wallet
    call    load_or_generate_wallet
    mov     byte [wallet_gen], 1
.have_wallet:

    ; Create/overwrite attestation file
    mov     ah, 3Ch
    mov     cx, 0
    mov     dx, attest_fn
    int     21h
    jc      .done
    mov     bx, ax

    ; Write attestation data
    ; Format for server submission
    mov     ah, 40h
    mov     cx, att_hdr_len
    mov     dx, att_hdr
    int     21h

    ; Wallet
    mov     ah, 40h
    mov     cx, 43
    mov     dx, wallet
    int     21h

    mov     ah, 40h
    mov     cx, 2
    mov     dx, crlf
    int     21h

    ; Layers
    mov     ah, 40h
    mov     cx, lay_ln_len
    mov     dx, lay_ln
    int     21h

    mov     al, [layers_passed]
    add     al, '0'
    mov     [numbuf], al
    mov     ah, 40h
    mov     cx, 1
    mov     dx, numbuf
    int     21h

    mov     ah, 40h
    mov     cx, 4
    mov     dx, slash7
    int     21h

    ; Emulator flag
    mov     ah, 40h
    mov     cx, emu_ln_len
    mov     dx, emu_ln
    int     21h

    cmp     byte [emulator_detected], 0
    je      .no_emu
    mov     ah, 40h
    mov     cx, 5
    mov     dx, true_str
    int     21h
    jmp     .ent_score
.no_emu:
    mov     ah, 40h
    mov     cx, 6
    mov     dx, false_str
    int     21h

.ent_score:
    ; Entropy score
    mov     ah, 40h
    mov     cx, ent_ln_len
    mov     dx, ent_ln
    int     21h

    ; Convert entropy to string
    mov     ax, [entropy_score]
    call    num_to_str
    mov     ah, 40h
    mov     cx, 5
    mov     dx, numbuf
    int     21h

    mov     ah, 40h
    mov     cx, 2
    mov     dx, crlf
    int     21h

    ; Node URL
    mov     ah, 40h
    mov     cx, node_ln_len
    mov     dx, node_ln
    int     21h

    ; Close
    mov     ah, 3Eh
    int     21h

    inc     word [attest_count]

.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Show attestation status
;---------------------------------------
show_attest_status:
    push    ax
    push    dx

    mov     ah, 02h
    mov     bh, 0
    mov     dh, 18
    mov     dl, 5
    int     10h

    mov     ah, 09h
    mov     dx, attest_msg
    int     21h

    mov     ax, [attest_count]
    call    print_dec

    mov     ah, 09h
    mov     dx, attest_suf
    int     21h

    pop     dx
    pop     ax
    ret

;---------------------------------------
; Load wallet from WALLET.TXT or generate new
;---------------------------------------
load_or_generate_wallet:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Try to open WALLET.TXT
    mov     ah, 3Dh
    mov     al, 0           ; Read-only
    mov     dx, wallet_fn
    int     21h
    jc      .generate_new   ; File doesn't exist, generate new

    ; File exists, read wallet
    mov     bx, ax          ; File handle
    mov     ah, 3Fh
    mov     cx, 43          ; RTC + 40 hex chars
    mov     dx, wallet
    int     21h

    ; Close file
    mov     ah, 3Eh
    int     21h

    ; Add $ terminator
    mov     byte [wallet+43], '$'

    ; Show message
    mov     ah, 09h
    mov     dx, wallet_loaded_msg
    int     21h
    jmp     .done

.generate_new:
    ; Generate new wallet
    call    generate_wallet

    ; Save wallet to WALLET.TXT
    mov     ah, 3Ch         ; Create file
    mov     cx, 0
    mov     dx, wallet_fn
    int     21h
    jc      .done           ; Failed to create

    mov     bx, ax          ; File handle
    mov     ah, 40h         ; Write
    mov     cx, 43
    mov     dx, wallet
    int     21h

    ; Close
    mov     ah, 3Eh
    int     21h

    ; Show message
    mov     ah, 09h
    mov     dx, wallet_saved_msg
    int     21h

.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Generate wallet
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
.cp:
    mov     al, [es:si]
    mov     [di], al
    inc     si
    inc     di
    loop    .cp

    xor     ax, ax
    int     1Ah
    mov     [entropy+8], dx
    mov     [entropy+10], cx

    mov     al, 0
    out     70h, al
    in      al, 71h
    mov     [entropy+12], al

    ; Hash
    mov     di, hash
    mov     cx, 20
    mov     al, 5Ah
.ih:
    mov     [di], al
    xor     al, cl
    ror     al, 1
    inc     di
    loop    .ih

    mov     si, entropy
    mov     di, hash
    mov     cx, 13
.xr:
    lodsb
    xor     [di], al
    rol     byte [di], 3
    inc     di
    loop    .xr

    ; Build wallet string
    mov     di, wallet
    mov     byte [di], 'R'
    inc     di
    mov     byte [di], 'T'
    inc     di
    mov     byte [di], 'C'
    inc     di

    mov     si, hash
    mov     cx, 20
.hex:
    lodsb
    call    byte2hex
    loop    .hex

    mov     byte [di], '$'

    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

byte2hex:
    push    ax
    push    bx
    mov     bx, hexch
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
; Clear keyboard buffer
;---------------------------------------
clear_keyboard_buffer:
    push    ax
.clear_loop:
    mov     ah, 01h         ; Check if key available
    int     16h
    jz      .clear_done     ; No key, done
    mov     ah, 00h         ; Read and discard key
    int     16h
    jmp     .clear_loop
.clear_done:
    pop     ax
    ret

;---------------------------------------
; Delay ~1 second
;---------------------------------------
delay_1sec:
    push    ax
    push    cx
    push    dx

    xor     ax, ax
    int     1Ah
    mov     cx, dx
    add     cx, 18          ; ~18 ticks = 1 sec
.wait:
    xor     ax, ax
    int     1Ah
    cmp     dx, cx
    jb      .wait

    pop     dx
    pop     cx
    pop     ax
    ret

;---------------------------------------
; Print AX as decimal
;---------------------------------------
print_dec:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     bx, 10
    xor     cx, cx
.div:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div
.pr:
    pop     dx
    add     dl, '0'
    mov     ah, 02h
    int     21h
    loop    .pr

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; Number to string in numbuf
num_to_str:
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

    mov     di, numbuf
    mov     bx, 10
    xor     cx, cx
.d:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .d
.p:
    pop     dx
    add     dl, '0'
    mov     [di], dl
    inc     di
    loop    .p
    mov     byte [di], 0

    pop     di
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
    db '  RUSTCHAIN CONTINUOUS MINER v1.0', 13, 10
    db '  Proof of Antiquity (RIP-PoA) - 7 Layer Anti-Cheat', 13, 10
    db ' ================================================================', 13, 10
    db '  Node: https://50.28.86.131 | Press ESC to stop', 13, 10
    db ' ================================================================', 13, 10
    db 13, 10, '$'

status_hdr:
    db '  Running 7-layer hardware verification...', 13, 10, 13, 10, '$'

layer_names:
    db '  [1] BIOS Signature...... $'
    times 32 - ($ - layer_names) db 0
    db '  [2] Timer Jitter........ $'
    times 64 - ($ - layer_names) db 0
    db '  [3] I/O Port Timing..... $'
    times 96 - ($ - layer_names) db 0
    db '  [4] Memory Timing....... $'
    times 128 - ($ - layer_names) db 0
    db '  [5] CPUID Hypervisor.... $'
    times 160 - ($ - layer_names) db 0
    db '  [6] IRQ Timing.......... $'
    times 192 - ($ - layer_names) db 0
    db '  [7] Entropy Quality..... $'
    times 224 - ($ - layer_names) db 0

pass_str:   db 'PASS', 13, 10, '$'
fail_str:   db 'FAIL', 13, 10, '$'

sum_lbl:    db 13, 10, '  Layers Passed: $'
of7_str:    db '/7', 13, 10, '$'
ent_lbl:    db '  Entropy Score: $'
bits_str:   db ' bits', 13, 10, '$'

emu_warning:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  EMULATION DETECTED - MINING WITH 1e-9 MULTIPLIER', 13, 10
    db ' ================================================================', 13, 10
    db '  Your system failed anti-cheat checks.', 13, 10
    db '  Mining continues but rewards = 1 billionth normal.', 13, 10
    db '  For full rewards: run on REAL vintage hardware!', 13, 10
    db ' ================================================================', 13, 10
    db 13, 10, '$'

frame0:
    db '    o/      ', 13, 10
    db '   /|  \    ', 13, 10
    db '   / \  [] [==]', 13, 10, '$'

frame1:
    db '    o--\    ', 13, 10
    db '   /|   []  ', 13, 10
    db '   / \ [==] ', 13, 10, '$'

frame2:
    db '  *CLINK*   ', 13, 10
    db '    o  []   ', 13, 10
    db '   /|\\/[==]', 13, 10, '$'

frame3:
    db '    o--/    ', 13, 10
    db '   /| []    ', 13, 10
    db '   / \\[==] ', 13, 10, '$'

block_lbl:  db 'Blocks: $'

attest_msg: db '  [Attestation #$'
attest_suf: db ' saved to ATTEST.TXT]          ', 13, 10, '$'

exit_msg:
    db 13, 10, 13, 10
    db '  Mining stopped. Final attestation saved.', 13, 10
    db '  Submit ATTEST.TXT to node for rewards.', 13, 10, '$'

hexch:      db '0123456789abcdef'
crlf:       db 13, 10

attest_fn:  db 'ATTEST.TXT', 0
wallet_fn:  db 'WALLET.TXT', 0

wallet_loaded_msg:  db '  [*] Loaded wallet from WALLET.TXT', 13, 10, '$'
wallet_saved_msg:   db '  [*] Generated new wallet, saved to WALLET.TXT', 13, 10, '$'
att_hdr:    db 'RUSTCHAIN_ATTESTATION_V1', 13, 10
            db 'NODE=https://50.28.86.131', 13, 10
            db 'WALLET='
att_hdr_len equ $ - att_hdr

lay_ln:     db 'LAYERS_PASSED='
lay_ln_len equ $ - lay_ln
slash7:     db '/7', 13, 10

emu_ln:     db 'EMULATOR_DETECTED='
emu_ln_len equ $ - emu_ln
true_str:   db 'true', 13, 10
false_str:  db 'false', 13, 10

ent_ln:     db 'ENTROPY_SCORE='
ent_ln_len equ $ - ent_ln

node_ln:    db 'SUBMIT_TO=https://50.28.86.131/attest/submit', 13, 10
node_ln_len equ $ - node_ln

section .bss

layers_passed:      resb 1
emulator_detected:  resb 1
layer_results:      resb 7
wallet_gen:         resb 1

jitter_var:         resw 1
entropy_score:      resw 1
blocks_mined:       resw 1
attest_count:       resw 1

membuf:             resb 512
entropy:            resb 16
hash:               resb 20
wallet:             resb 64
numbuf:             resb 8
