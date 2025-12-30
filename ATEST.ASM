; Quick Anti-Cheat Test - outputs to screen only, no wait
org 100h

section .text
start:
    ; Display message
    mov     ah, 09h
    mov     dx, msg1
    int     21h

    ; Quick BIOS scan for DOSBox
    mov     ax, 0F000h
    mov     es, ax
    xor     di, di
    mov     cx, 0FFF0h

.scan:
    cmp     word [es:di], 'DO'
    jne     .next
    cmp     word [es:di+2], 'SB'
    je      .found_dosbox
.next:
    inc     di
    loop    .scan

    ; Check for SeaBIOS (QEMU/Proxmox)
    xor     di, di
    mov     cx, 0FFF0h
.scan2:
    cmp     dword [es:di], 'SeaB'
    je      .found_seabios
    inc     di
    loop    .scan2

    ; Not found
    mov     ah, 09h
    mov     dx, msg_real
    int     21h
    jmp     .done

.found_dosbox:
    mov     ah, 09h
    mov     dx, msg_dosbox
    int     21h
    jmp     .done

.found_seabios:
    mov     ah, 09h
    mov     dx, msg_seabios
    int     21h

.done:
    ; Exit immediately
    mov     ax, 4C00h
    int     21h

section .data
msg1:       db 'Anti-Cheat Quick Test', 13, 10, '$'
msg_dosbox: db 'DETECTED: DOSBox Emulator', 13, 10, '$'
msg_seabios: db 'DETECTED: SeaBIOS (QEMU/Proxmox)', 13, 10, '$'
msg_real:   db 'No emulator signatures found', 13, 10, '$'
