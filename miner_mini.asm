; RustChain Mini Miner - 16-bit Real Mode DOS
; For 8086/286/386/486/Pentium
; Assembles with: nasm -f bin -o MINER.COM miner_mini.asm
;
; Features:
;   - Auto-wallet generation from BIOS/hardware entropy
;   - ASCII mining animation!
;   - Saves wallet to WALLET.TXT

org 100h                    ; COM file format

section .text

start:
    ; Clear screen
    mov     ax, 0003h
    int     10h

    ; Display banner
    mov     ah, 09h
    mov     dx, banner
    int     21h

    ; Show mining animation while generating entropy
    call    mining_animation

    ; Get BIOS date for entropy
    mov     ax, 0F000h
    mov     es, ax
    mov     si, 0FFF5h      ; BIOS date location
    mov     di, entropy_buf
    mov     cx, 8
.copy_bios:
    mov     al, [es:si]
    mov     [di], al
    inc     si
    inc     di
    loop    .copy_bios

    ; Get timer ticks for more entropy
    xor     ax, ax
    int     1Ah             ; Get timer ticks
    mov     [entropy_buf+8], dx
    mov     [entropy_buf+10], cx

    ; Read CMOS/RTC for entropy
    mov     al, 0           ; Seconds
    out     70h, al
    in      al, 71h
    mov     [entropy_buf+12], al

    mov     al, 2           ; Minutes
    out     70h, al
    in      al, 71h
    mov     [entropy_buf+13], al

    mov     al, 4           ; Hours
    out     70h, al
    in      al, 71h
    mov     [entropy_buf+14], al

    ; Simple hash to generate wallet
    call    hash_entropy

    ; Build wallet address string
    mov     di, wallet_addr
    mov     byte [di], 'R'
    inc     di
    mov     byte [di], 'T'
    inc     di
    mov     byte [di], 'C'
    inc     di

    ; Convert hash bytes to hex
    mov     si, hash_result
    mov     cx, 20          ; 20 bytes = 40 hex chars
.hex_loop:
    lodsb
    call    byte_to_hex
    loop    .hex_loop

    mov     byte [di], 0    ; Null terminate

    ; Display wallet
    mov     ah, 09h
    mov     dx, wallet_msg
    int     21h

    mov     ah, 09h
    mov     dx, wallet_addr
    int     21h

    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Save wallet to file
    call    save_wallet

    ; Display instructions
    mov     ah, 09h
    mov     dx, instr_msg
    int     21h

    ; Wait for keypress
    mov     ah, 01h
    int     21h

    ; Exit
    mov     ax, 4C00h
    int     21h

; Fun ASCII mining animation!
mining_animation:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     cx, 30          ; 30 animation frames

.anim_loop:
    push    cx

    ; Move cursor to animation position
    mov     ah, 02h
    mov     bh, 0
    mov     dh, 12          ; Row 12
    mov     dl, 15          ; Column 15
    int     10h

    ; Get frame number (0-3)
    pop     cx
    push    cx
    mov     ax, cx
    and     ax, 3

    ; Display appropriate frame
    cmp     al, 0
    je      .frame0
    cmp     al, 1
    je      .frame1
    cmp     al, 2
    je      .frame2
    jmp     .frame3

.frame0:
    mov     dx, anim0
    jmp     .show_frame
.frame1:
    mov     dx, anim1
    jmp     .show_frame
.frame2:
    mov     dx, anim2
    jmp     .show_frame
.frame3:
    mov     dx, anim3

.show_frame:
    mov     ah, 09h
    int     21h

    ; Delay
    mov     ah, 86h
    mov     cx, 0
    mov     dx, 50000       ; ~50ms delay
    int     15h

    ; Alternative delay for older systems
    mov     bx, 5000
.delay:
    dec     bx
    jnz     .delay

    pop     cx
    loop    .anim_loop

    ; Clear animation area
    mov     ah, 02h
    mov     bh, 0
    mov     dh, 10
    mov     dl, 0
    int     10h

    mov     ah, 09h
    mov     dx, done_msg
    int     21h

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; Simple hash function (XOR-based, not cryptographic)
hash_entropy:
    push    ax
    push    bx
    push    cx
    push    si
    push    di

    ; Initialize hash with seed
    mov     di, hash_result
    mov     cx, 20
    mov     al, 5Ah         ; Seed
.init_hash:
    mov     [di], al
    xor     al, cl
    add     al, 17h
    inc     di
    loop    .init_hash

    ; XOR with entropy buffer
    mov     si, entropy_buf
    mov     di, hash_result
    mov     cx, 15
.xor_loop:
    lodsb
    xor     [di], al
    rol     byte [di], 3
    inc     di
    cmp     di, hash_result + 20
    jb      .no_wrap
    mov     di, hash_result
.no_wrap:
    loop    .xor_loop

    ; Additional mixing rounds
    mov     bx, 3           ; 3 rounds
.mix_round:
    mov     si, hash_result
    mov     di, hash_result
    mov     cx, 20
.mix_loop:
    lodsb
    add     al, cl
    xor     al, bl
    ror     al, 1
    stosb
    loop    .mix_loop
    dec     bx
    jnz     .mix_round

    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

; Convert byte in AL to two hex chars at [DI]
byte_to_hex:
    push    ax
    push    bx

    mov     bx, hex_chars

    ; High nibble
    mov     ah, al
    shr     ah, 4
    and     ah, 0Fh
    push    ax
    mov     al, ah
    xlat
    mov     [di], al
    inc     di
    pop     ax

    ; Low nibble
    and     al, 0Fh
    xlat
    mov     [di], al
    inc     di

    pop     bx
    pop     ax
    ret

; Save wallet to WALLET.TXT
save_wallet:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Create/truncate file
    mov     ah, 3Ch
    mov     cx, 0           ; Normal file
    mov     dx, wallet_file
    int     21h
    jc      .error

    mov     bx, ax          ; File handle

    ; Write wallet address
    mov     ah, 40h
    mov     cx, 43          ; RTC + 40 hex chars
    mov     dx, wallet_addr
    int     21h

    ; Write newline
    mov     ah, 40h
    mov     cx, 2
    mov     dx, newline
    int     21h

    ; Close file
    mov     ah, 3Eh
    int     21h

    ; Success message
    mov     ah, 09h
    mov     dx, saved_msg
    int     21h
    jmp     .done

.error:
    mov     ah, 09h
    mov     dx, error_msg
    int     21h

.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

section .data

banner:
    db 13, 10
    db ' ======================================================', 13, 10
    db '      RUSTCHAIN - Proof of Antiquity (RIP-PoA)', 13, 10
    db ' ======================================================', 13, 10
    db 13, 10
    db '   Every vintage computer has historical potential', 13, 10
    db 13, 10
    db '   DOS Miner - For 8086/286/386/486/Pentium', 13, 10
    db '   Node: 50.28.86.131 | Dev Fee: 0.001 RTC/epoch', 13, 10
    db 13, 10
    db '   ANTIQUITY BONUS: Older CPU = Higher Rewards!', 13, 10
    db ' ======================================================', 13, 10
    db 13, 10
    db '$'

; Mining animation frames - pickaxe swinging!
anim0:
    db '        ', 13, 10
    db '    o/', 13, 10
    db '   /|  \', 13, 10
    db '   / \  []', 13, 10
    db '       [==]', 13, 10
    db '$'

anim1:
    db '        ', 13, 10
    db '    o--\', 13, 10
    db '   /|   []', 13, 10
    db '   / \ [==]', 13, 10
    db '        ', 13, 10
    db '$'

anim2:
    db '     *CLINK*', 13, 10
    db '    o  []', 13, 10
    db '   /|\/[==]', 13, 10
    db '   / \   ', 13, 10
    db '        ', 13, 10
    db '$'

anim3:
    db '        ', 13, 10
    db '    o--/', 13, 10
    db '   /| []', 13, 10
    db '   / \[==]', 13, 10
    db '        ', 13, 10
    db '$'

done_msg:
    db 13, 10, 13, 10
    db '  [*] Mining entropy collected!', 13, 10
    db 13, 10
    db '$'

wallet_msg:
    db 13, 10, '  Your Wallet Address:', 13, 10, '  ', '$'

saved_msg:
    db 13, 10, '  [OK] Saved to WALLET.TXT', 13, 10, '$'

error_msg:
    db 13, 10, '  [ERROR] Could not save wallet!', 13, 10, '$'

instr_msg:
    db 13, 10
    db ' ======================================================', 13, 10
    db '  IMPORTANT: Backup WALLET.TXT to floppy disk!', 13, 10
    db ' ======================================================', 13, 10
    db 13, 10
    db '  PROOF OF ANTIQUITY MULTIPLIERS:', 13, 10
    db '  +------------------+------------+', 13, 10
    db '  | CPU Class        | Multiplier |', 13, 10
    db '  +------------------+------------+', 13, 10
    db '  | 8086/8088 (1978) |    4.0x    |', 13, 10
    db '  | 80286     (1982) |    3.8x    |', 13, 10
    db '  | 80386     (1985) |    3.5x    |', 13, 10
    db '  | 80486     (1989) |    3.0x    |', 13, 10
    db '  | Pentium   (1993) |    2.5x    |', 13, 10
    db '  | Modern    (2000+)|    1.0x    |', 13, 10
    db '  +------------------+------------+', 13, 10
    db 13, 10
    db '  NOTE: VMs/Emulators detected = minimal rewards', 13, 10
    db '        Real vintage hardware = full bonus!', 13, 10
    db ' ======================================================', 13, 10
    db 13, 10
    db '  Press any key to exit...', 13, 10
    db '$'

newline:
    db 13, 10, '$'

wallet_file:
    db 'WALLET.TXT', 0

hex_chars:
    db '0123456789abcdef'

section .bss

entropy_buf:    resb 16
hash_result:    resb 20
wallet_addr:    resb 64
