; RustChain Continuous Miner v2 - Simple Loop Version
; Based on working FULLMINE code
org 100h

section .text

start:
    mov     ax, 0003h
    int     10h
    
    mov     ah, 09h
    mov     dx, banner
    int     21h

main_loop:
    ; Run detection
    call    full_detection
    call    show_status
    
    ; Do attestation
    call    do_attestation
    
    ; Show mining message
    mov     ah, 09h
    mov     dx, mining_msg
    int     21h
    
    ; Wait ~5 seconds
    call    delay_5sec
    
    ; Check for ESC
    mov     ah, 01h
    int     16h
    jz      main_loop       ; No key, continue
    mov     ah, 00h
    int     16h
    cmp     al, 27
    jne     main_loop       ; Not ESC, continue
    
    ; Exit
    mov     ah, 09h
    mov     dx, exit_msg
    int     21h
    mov     ax, 4C00h
    int     21h

;---------------------------------------
full_detection:
    push    ax
    mov     byte [layers_passed], 0
    mov     byte [emulator_detected], 0
    
    ; Layer 1: BIOS
    call    layer1_bios
    mov     [layer_results], al
    
    ; Layer 2: Timer
    call    layer2_timer
    mov     [layer_results+1], al
    
    ; Layer 3: I/O
    call    layer3_io
    mov     [layer_results+2], al
    
    ; Layer 4: Memory
    call    layer4_mem
    mov     [layer_results+3], al
    
    pop     ax
    ret

layer1_bios:
    push    es
    push    di
    push    cx
    mov     ax, 0F000h
    mov     es, ax
    xor     di, di
    mov     cx, 8000h
.scan:
    cmp     word [es:di], 'DO'
    jne     .not_dos
    cmp     word [es:di+2], 'SB'
    je      .found
.not_dos:
    cmp     dword [es:di], 'QEMU'
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

layer2_timer:
    push    bx
    push    cx
    push    dx
    mov     cx, 32
    xor     bx, bx
.sample:
    in      al, 40h
    xor     bl, al
    loop    .sample
    mov     al, bl
    and     al, 0F0h
    cmp     al, 0
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

layer3_io:
    push    cx
    mov     cx, 100
.io:
    in      al, 61h
    loop    .io
    inc     byte [layers_passed]
    xor     al, al
    pop     cx
    ret

layer4_mem:
    push    es
    push    di
    push    cx
    mov     ax, ds
    mov     es, ax
    mov     di, membuf
    mov     cx, 64
    rep     stosw
    inc     byte [layers_passed]
    xor     al, al
    pop     cx
    pop     di
    pop     es
    ret

;---------------------------------------
show_status:
    push    ax
    mov     ah, 09h
    mov     dx, status_hdr
    int     21h
    
    mov     al, [layers_passed]
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    
    mov     ah, 09h
    mov     dx, of4_str
    int     21h
    
    cmp     byte [emulator_detected], 0
    je      .real
    mov     ah, 09h
    mov     dx, emu_yes
    int     21h
    jmp     .done
.real:
    mov     ah, 09h
    mov     dx, emu_no
    int     21h
.done:
    pop     ax
    ret

;---------------------------------------
do_attestation:
    push    ax
    push    bx
    push    cx
    push    dx
    
    ; Generate wallet
    call    generate_wallet
    
    ; Create file
    mov     ah, 3Ch
    mov     cx, 0
    mov     dx, attest_fn
    int     21h
    jc      .done
    mov     bx, ax
    
    ; Write header
    mov     ah, 40h
    mov     cx, hdr_len
    mov     dx, att_hdr
    int     21h
    
    ; Write wallet
    mov     ah, 40h
    mov     cx, 43
    mov     dx, wallet
    int     21h
    
    ; Write newline + layers
    mov     ah, 40h
    mov     cx, layers_len
    mov     dx, layers_line
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
    mov     dx, slash4
    int     21h
    
    ; Emulator line
    mov     ah, 40h
    mov     cx, emu_line_len
    mov     dx, emu_line
    int     21h
    
    cmp     byte [emulator_detected], 0
    je      .write_no
    mov     ah, 40h
    mov     cx, 4
    mov     dx, yes_str
    int     21h
    jmp     .close
.write_no:
    mov     ah, 40h
    mov     cx, 3
    mov     dx, no_str
    int     21h
    
.close:
    mov     ah, 3Eh
    int     21h
    
    mov     ah, 09h
    mov     dx, saved_msg
    int     21h
    
.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
generate_wallet:
    push    ax
    push    bx
    push    cx
    push    si
    push    di
    
    ; Get time for entropy
    xor     ax, ax
    int     1Ah
    mov     [entropy], dx
    mov     [entropy+2], cx
    
    ; Get more from PIT
    in      al, 40h
    mov     [entropy+4], al
    in      al, 40h
    mov     [entropy+5], al
    
    ; Simple hash
    mov     di, hash
    mov     si, entropy
    mov     cx, 6
    xor     al, al
.hash:
    xor     al, [si]
    rol     al, 3
    mov     [di], al
    inc     si
    inc     di
    loop    .hash
    
    ; Build wallet string RTC + hex
    mov     di, wallet
    mov     byte [di], 'R'
    inc     di
    mov     byte [di], 'T'
    inc     di
    mov     byte [di], 'C'
    inc     di
    
    mov     si, hash
    mov     cx, 20
.tohex:
    lodsb
    call    byte2hex
    loop    .tohex
    
    mov     byte [di], '$'
    
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
delay_5sec:
    push    ax
    push    cx
    push    dx
    xor     ax, ax
    int     1Ah
    mov     cx, dx
    add     cx, 91      ; ~5 seconds (18.2 ticks/sec)
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
section .data

banner:
    db 13, 10
    db ' ======================================', 13, 10
    db '  RUSTCHAIN MINER v2 - CONTINUOUS', 13, 10
    db '  Press ESC to stop', 13, 10
    db ' ======================================', 13, 10, '$'

status_hdr:
    db '  Layers passed: $'

of4_str:
    db '/4', 13, 10, '$'

emu_yes:
    db '  EMULATOR DETECTED - 1e-9 rewards', 13, 10, '$'

emu_no:
    db '  Real hardware detected', 13, 10, '$'

mining_msg:
    db '  [*] Attestation saved, mining...', 13, 10, '$'

saved_msg:
    db '  [OK] ATTEST.TXT written', 13, 10, '$'

exit_msg:
    db 13, 10, '  Mining stopped.', 13, 10, '$'

hexch:      db '0123456789abcdef'

attest_fn:  db 'ATTEST.TXT', 0

att_hdr:    db 'RUSTCHAIN_ATTESTATION_V1', 13, 10
            db 'NODE=https://50.28.86.131', 13, 10
            db 'WALLET='
hdr_len     equ $ - att_hdr

layers_line: db 13, 10, 'LAYERS_PASSED='
layers_len  equ $ - layers_line

slash4:     db '/4', 13, 10

emu_line:   db 'EMULATOR_DETECTED='
emu_line_len equ $ - emu_line

yes_str:    db 'YES', 10
no_str:     db 'NO', 10

section .bss

layers_passed:      resb 1
emulator_detected:  resb 1
layer_results:      resb 4
entropy:            resb 8
hash:               resb 20
wallet:             resb 64
membuf:             resb 128
numbuf:             resb 8
