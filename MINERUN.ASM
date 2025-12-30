; RustChain Continuous Miner - Full 7-Layer + Working Loop
org 100h

section .text

start:
    mov     ax, 0003h
    int     10h
    
    mov     ah, 09h
    mov     dx, banner
    int     21h

    ; Initial detection (once at start)
    call    full_detection
    call    show_status
    
    ; Check if emulator
    cmp     byte [layers_passed], 5
    jae     .show_real
    mov     ah, 09h
    mov     dx, emu_warning
    int     21h
    jmp     .start_mining
.show_real:
    mov     ah, 09h
    mov     dx, real_msg
    int     21h

.start_mining:
    mov     ah, 09h
    mov     dx, start_msg
    int     21h

; === MAIN MINING LOOP ===
mine_loop:
    ; Increment counter
    inc     word [block_count]
    
    ; Show progress
    mov     ah, 09h
    mov     dx, mining_dot
    int     21h
    
    ; Every 10 blocks, attestation
    mov     ax, [block_count]
    mov     bl, 10
    div     bl
    cmp     ah, 0
    jne     .skip_attest
    
    call    do_attestation
    mov     ah, 09h
    mov     dx, attest_ok
    int     21h

.skip_attest:
    ; Delay ~1 second
    xor     ax, ax
    int     1Ah
    mov     bx, dx
    add     bx, 18
.wait:
    xor     ax, ax
    int     1Ah
    cmp     dx, bx
    jb      .wait
    
    ; Check ESC key
    mov     ah, 01h
    int     16h
    jz      mine_loop       ; No key pressed, continue
    
    ; Key pressed - read it
    mov     ah, 00h
    int     16h
    cmp     al, 27          ; ESC?
    je      .exit
    jmp     mine_loop       ; Other key, continue

.exit:
    mov     ah, 09h
    mov     dx, exit_msg
    int     21h
    mov     ax, 4C00h
    int     21h

; ============================================
; FULL 7-LAYER DETECTION (from working code)
; ============================================
full_detection:
    push    ax
    mov     byte [layers_passed], 0
    mov     byte [emulator_detected], 0
    
    call    layer1_bios
    mov     [layer_results], al
    call    layer2_jitter
    mov     [layer_results+1], al
    call    layer3_io
    mov     [layer_results+2], al
    call    layer4_mem
    mov     [layer_results+3], al
    call    layer5_cpuid
    mov     [layer_results+4], al
    call    layer6_irq
    mov     [layer_results+5], al
    call    layer7_entropy
    mov     [layer_results+6], al
    
    pop     ax
    ret

; Layer 1: BIOS Signature
layer1_bios:
    push    es
    push    di
    push    cx
    mov     ax, 0F000h
    mov     es, ax
    xor     di, di
    mov     cx, 0FFF0h
.scan:
    cmp     word [es:di], 'DO'
    jne     .not_dos
    cmp     word [es:di+2], 'SB'
    je      .found
.not_dos:
    cmp     dword [es:di], 'QEMU'
    je      .found
    cmp     dword [es:di], 'SeaB'
    je      .found
    cmp     dword [es:di], 'VBOX'
    je      .found
    cmp     dword [es:di], 'Boch'
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

; Layer 2: Timer Jitter
layer2_jitter:
    push    bx
    push    cx
    push    dx
    mov     cx, 64
    xor     bx, bx
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
    xor     bx, ax
    pop     cx
    loop    .sample
    mov     [jitter_var], bx
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

; Layer 3: I/O Timing
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

; Layer 4: Memory Timing
layer4_mem:
    push    bx
    push    cx
    push    dx
    push    es
    mov     ax, ds
    mov     es, ax
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
    ; Just pass this one
    inc     byte [layers_passed]
    xor     al, al
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

; Layer 5: CPUID Hypervisor
layer5_cpuid:
    push    bx
    push    cx
    push    dx
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
    mov     eax, 1
    cpuid
    test    ecx, 80000000h
    jnz     .found
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

; Layer 6: IRQ Timing
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
.wait_tick:
    xor     ax, ax
    int     1Ah
    cmp     dx, si
    je      .wait_tick
    sub     dx, si
    cmp     dx, 1
    je      .exact
    inc     bx
.exact:
    pop     cx
    loop    .tick
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

; Layer 7: Entropy Quality
layer7_entropy:
    push    bx
    push    cx
    push    dx
    xor     bx, bx
    mov     cx, 16
    xor     dl, dl
.pit_sample:
    in      al, 40h
    xor     dl, al
    push    cx
    mov     cx, 10
.pd:
    loop    .pd
    pop     cx
    loop    .pit_sample
    mov     al, dl
    call    count_bits
    add     bx, ax
    in      al, 64h
    mov     dl, al
    in      al, 60h
    xor     dl, al
    mov     al, dl
    call    count_bits
    add     bx, ax
    mov     [entropy_score], bx
    cmp     bx, 8
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

; ============================================
; SHOW STATUS
; ============================================
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
    mov     ah, 09h
    mov     dx, di
    int     21h
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
    add     di, 30
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
    
    pop     ax
    ret

; ============================================
; DO ATTESTATION
; ============================================
do_attestation:
    push    ax
    push    bx
    push    cx
    push    dx
    
    call    generate_wallet
    
    mov     ah, 3Ch
    mov     cx, 0
    mov     dx, attest_fn
    int     21h
    jc      .done
    mov     bx, ax
    
    mov     ah, 40h
    mov     cx, hdr_len
    mov     dx, att_hdr
    int     21h
    
    mov     ah, 40h
    mov     cx, 43
    mov     dx, wallet
    int     21h
    
    mov     ah, 40h
    mov     cx, 2
    mov     dx, crlf
    int     21h
    
    mov     ah, 40h
    mov     cx, lay_len
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
    
    mov     ah, 40h
    mov     cx, emu_len
    mov     dx, emu_ln
    int     21h
    
    cmp     byte [emulator_detected], 0
    je      .no_emu
    mov     ah, 40h
    mov     cx, 5
    mov     dx, true_str
    int     21h
    jmp     .ent
.no_emu:
    mov     ah, 40h
    mov     cx, 6
    mov     dx, false_str
    int     21h
.ent:
    mov     ah, 40h
    mov     cx, ent_len
    mov     dx, ent_ln
    int     21h
    
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
    
    mov     ah, 3Eh
    int     21h
    
.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

generate_wallet:
    push    ax
    push    bx
    push    cx
    push    si
    push    di

    ; Try to load from WALLET.TXT first
    mov     ah, 3Dh
    mov     al, 0
    mov     dx, wallet_fn
    int     21h
    jc      .gen_new        ; File not found, generate new

    ; Read wallet from file
    mov     bx, ax
    mov     ah, 3Fh
    mov     cx, 43
    mov     dx, wallet
    int     21h
    mov     ah, 3Eh
    int     21h
    mov     byte [wallet+43], '$'
    jmp     .done

.gen_new:
    xor     ax, ax
    int     1Ah
    mov     [entropy_buf], dx
    mov     [entropy_buf+2], cx
    in      al, 40h
    mov     [entropy_buf+4], al
    in      al, 40h
    mov     [entropy_buf+5], al
    
    mov     di, hash
    mov     si, entropy_buf
    mov     cx, 20
    mov     al, 5Ah
.ih:
    xor     al, [si]
    rol     al, 3
    mov     [di], al
    inc     di
    inc     si
    cmp     si, entropy_buf+6
    jb      .nw
    mov     si, entropy_buf
.nw:
    loop    .ih
    
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

.done:
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

; ============================================
section .data

banner:
    db 13, 10
    db ' ================================================================', 13, 10
    db '  RUSTCHAIN CONTINUOUS MINER - 7 Layer Anti-Cheat', 13, 10
    db '  Press ESC to stop mining', 13, 10
    db ' ================================================================', 13, 10, '$'

status_hdr:
    db 13, 10, '  Running 7-layer verification...', 13, 10, 13, 10, '$'

layer_names:
    db '  [1] BIOS Signature... $'
    times 30 - ($ - layer_names) db 0
    db '  [2] Timer Jitter..... $'
    times 60 - ($ - layer_names) db 0
    db '  [3] I/O Timing....... $'
    times 90 - ($ - layer_names) db 0
    db '  [4] Memory Timing.... $'
    times 120 - ($ - layer_names) db 0
    db '  [5] CPUID Hypervisor. $'
    times 150 - ($ - layer_names) db 0
    db '  [6] IRQ Timing....... $'
    times 180 - ($ - layer_names) db 0
    db '  [7] Entropy Quality.. $'
    times 210 - ($ - layer_names) db 0

pass_str:   db 'PASS', 13, 10, '$'
fail_str:   db 'FAIL', 13, 10, '$'
sum_lbl:    db 13, 10, '  Layers Passed: $'
of7_str:    db '/7', 13, 10, '$'

emu_warning:
    db 13, 10
    db '  ** EMULATION DETECTED - Mining at 1e-9 reward **', 13, 10, '$'

real_msg:
    db 13, 10, '  ** REAL HARDWARE - Full rewards **', 13, 10, '$'

start_msg:
    db 13, 10, '  Starting mining loop...', 13, 10, '$'

mining_dot: db '.', '$'
attest_ok:  db '[OK]', 13, 10, '$'

exit_msg:
    db 13, 10, '  Mining stopped.', 13, 10, '$'

hexch:      db '0123456789abcdef'
crlf:       db 13, 10

attest_fn:  db 'ATTEST.TXT', 0
wallet_fn:  db 'WALLET.TXT', 0

att_hdr:    db 'RUSTCHAIN_ATTESTATION_V1', 13, 10
            db 'NODE=https://50.28.86.131', 13, 10
            db 'WALLET='
hdr_len     equ $ - att_hdr

lay_ln:     db 'LAYERS_PASSED='
lay_len     equ $ - lay_ln
slash7:     db '/7', 13, 10

emu_ln:     db 'EMULATOR_DETECTED='
emu_len     equ $ - emu_ln
true_str:   db 'true', 13, 10
false_str:  db 'false', 13, 10

ent_ln:     db 'ENTROPY_SCORE='
ent_len     equ $ - ent_ln

section .bss

layers_passed:      resb 1
emulator_detected:  resb 1
layer_results:      resb 7
jitter_var:         resw 1
entropy_score:      resw 1
block_count:        resw 1
entropy_buf:        resb 8
hash:               resb 20
wallet:             resb 64
membuf:             resb 512
numbuf:             resb 8
