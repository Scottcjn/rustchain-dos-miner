; Quick Anti-Cheat Test - writes result to DETECT.TXT
org 100h

section .text
start:
    ; Create output file
    mov     ah, 3Ch
    mov     cx, 0
    mov     dx, filename
    int     21h
    jc      .no_file
    mov     [filehandle], ax

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

    ; Check for QEMU
    xor     di, di
    mov     cx, 0FFF0h
.scan3:
    cmp     dword [es:di], 'QEMU'
    je      .found_qemu
    inc     di
    loop    .scan3

    ; Not found
    mov     si, msg_real
    jmp     .write

.found_dosbox:
    mov     si, msg_dosbox
    jmp     .write

.found_seabios:
    mov     si, msg_seabios
    jmp     .write

.found_qemu:
    mov     si, msg_qemu

.write:
    ; Write to file
    mov     bx, [filehandle]
    mov     cx, 40
    mov     dx, si
    mov     ah, 40h
    int     21h

    ; Close file
    mov     ah, 3Eh
    mov     bx, [filehandle]
    int     21h

.no_file:
    ; Exit
    mov     ax, 4C00h
    int     21h

section .data
filename:   db 'DETECT.TXT', 0
msg_dosbox: db 'EMULATOR=DOSBox', 13, 10, 'LAYER1=FAIL', 13, 10
msg_seabios: db 'EMULATOR=SeaBIOS/QEMU', 13, 10, 'LAYER1=FAIL'
msg_qemu:   db 'EMULATOR=QEMU', 13, 10, 'LAYER1=FAIL', 13, 10
msg_real:   db 'EMULATOR=NONE', 13, 10, 'LAYER1=PASS', 13, 10

section .bss
filehandle: resw 1
