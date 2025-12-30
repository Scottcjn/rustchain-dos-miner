; RustChain Hardware Scraper - 16-bit DOS
; Collects BIOS info, serial numbers, ISA bus detection
; For RIP-PoA (Proof of Antiquity) hardware fingerprinting
;
; Assembles with: nasm -f bin -o HWSCRAPE.COM hwscrape.asm

org 100h

section .text

start:
    ; Clear screen
    mov     ax, 0003h
    int     10h

    ; Display header
    mov     ah, 09h
    mov     dx, header_msg
    int     21h

    ; === BIOS Information ===
    mov     ah, 09h
    mov     dx, bios_header
    int     21h

    ; Get BIOS date (F000:FFF5, 8 bytes)
    call    get_bios_date

    ; Get BIOS signature byte (F000:FFFE)
    call    get_bios_signature

    ; Scan BIOS for vendor strings
    call    scan_bios_strings

    ; === System Information ===
    mov     ah, 09h
    mov     dx, sys_header
    int     21h

    ; Get equipment flags
    call    get_equipment

    ; Get conventional memory
    call    get_conv_memory

    ; Get extended memory (if available)
    call    get_ext_memory

    ; === CPU Detection ===
    mov     ah, 09h
    mov     dx, cpu_header
    int     21h

    call    detect_cpu

    ; === ISA Bus Detection ===
    mov     ah, 09h
    mov     dx, isa_header
    int     21h

    call    detect_isa_devices

    ; === Serial Numbers ===
    mov     ah, 09h
    mov     dx, serial_header
    int     21h

    call    get_serial_numbers

    ; === CMOS/RTC Data ===
    mov     ah, 09h
    mov     dx, cmos_header
    int     21h

    call    dump_cmos

    ; Done
    mov     ah, 09h
    mov     dx, done_msg
    int     21h

    ; Wait for key
    mov     ah, 01h
    int     21h

    ; Exit
    mov     ax, 4C00h
    int     21h

;---------------------------------------
; Get BIOS date from F000:FFF5
;---------------------------------------
get_bios_date:
    push    ax
    push    bx
    push    cx
    push    si
    push    es

    mov     ah, 09h
    mov     dx, date_label
    int     21h

    ; Point to BIOS date
    mov     ax, 0F000h
    mov     es, ax
    mov     si, 0FFF5h

    ; Print 8 characters
    mov     cx, 8
.print_date:
    mov     al, [es:si]
    cmp     al, 0
    je      .skip_char
    mov     dl, al
    mov     ah, 02h
    int     21h
.skip_char:
    inc     si
    loop    .print_date

    mov     ah, 09h
    mov     dx, newline
    int     21h

    pop     es
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Get BIOS signature byte
;---------------------------------------
get_bios_signature:
    push    ax
    push    bx
    push    es

    mov     ah, 09h
    mov     dx, sig_label
    int     21h

    mov     ax, 0F000h
    mov     es, ax
    mov     al, [es:0FFFEh]

    ; Print as hex
    call    print_hex_byte

    ; Interpret signature
    mov     ah, 09h
    cmp     al, 0FFh
    je      .is_pc
    cmp     al, 0FEh
    je      .is_xt
    cmp     al, 0FDh
    je      .is_pcjr
    cmp     al, 0FCh
    je      .is_at
    cmp     al, 0FBh
    je      .is_xt_enh
    cmp     al, 0FAh
    je      .is_ps2_30
    cmp     al, 0F9h
    je      .is_pc_conv
    cmp     al, 0F8h
    je      .is_ps2_80
    jmp     .unknown

.is_pc:
    mov     dx, sig_pc
    jmp     .print_type
.is_xt:
    mov     dx, sig_xt
    jmp     .print_type
.is_pcjr:
    mov     dx, sig_pcjr
    jmp     .print_type
.is_at:
    mov     dx, sig_at
    jmp     .print_type
.is_xt_enh:
    mov     dx, sig_xt_enh
    jmp     .print_type
.is_ps2_30:
    mov     dx, sig_ps2_30
    jmp     .print_type
.is_pc_conv:
    mov     dx, sig_pc_conv
    jmp     .print_type
.is_ps2_80:
    mov     dx, sig_ps2_80
    jmp     .print_type
.unknown:
    mov     dx, sig_unknown

.print_type:
    int     21h

    pop     es
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Scan BIOS ROM for vendor strings
;---------------------------------------
scan_bios_strings:
    push    ax
    push    bx
    push    cx
    push    si
    push    di
    push    es

    mov     ah, 09h
    mov     dx, vendor_label
    int     21h

    ; Search F000:0000 - F000:FFFF
    mov     ax, 0F000h
    mov     es, ax

    ; Look for common BIOS vendor strings
    ; AMI
    mov     di, str_ami
    call    search_bios_string
    jc      .found_ami

    ; Award
    mov     di, str_award
    call    search_bios_string
    jc      .found_award

    ; Phoenix
    mov     di, str_phoenix
    call    search_bios_string
    jc      .found_phoenix

    ; IBM
    mov     di, str_ibm
    call    search_bios_string
    jc      .found_ibm

    ; Compaq
    mov     di, str_compaq
    call    search_bios_string
    jc      .found_compaq

    ; Dell
    mov     di, str_dell
    call    search_bios_string
    jc      .found_dell

    ; Unknown
    mov     ah, 09h
    mov     dx, vendor_unknown
    int     21h
    jmp     .done

.found_ami:
    mov     ah, 09h
    mov     dx, vendor_ami
    int     21h
    jmp     .done

.found_award:
    mov     ah, 09h
    mov     dx, vendor_award
    int     21h
    jmp     .done

.found_phoenix:
    mov     ah, 09h
    mov     dx, vendor_phoenix
    int     21h
    jmp     .done

.found_ibm:
    mov     ah, 09h
    mov     dx, vendor_ibm
    int     21h
    jmp     .done

.found_compaq:
    mov     ah, 09h
    mov     dx, vendor_compaq
    int     21h
    jmp     .done

.found_dell:
    mov     ah, 09h
    mov     dx, vendor_dell
    int     21h

.done:
    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

; Search for string at DS:DI in BIOS (ES already F000h)
; Returns CF set if found
search_bios_string:
    push    ax
    push    cx
    push    si
    push    di

    xor     si, si          ; Start at F000:0000
    mov     cx, 0FFF0h      ; Search range

.search_loop:
    push    cx
    push    si
    push    di

    ; Get string length
    xor     cx, cx
    push    di
.strlen:
    cmp     byte [di], 0
    je      .got_len
    inc     di
    inc     cx
    jmp     .strlen
.got_len:
    pop     di

    ; Compare
.cmp_loop:
    jcxz    .found
    mov     al, [es:si]
    cmp     al, [di]
    jne     .not_match
    inc     si
    inc     di
    dec     cx
    jmp     .cmp_loop

.not_match:
    pop     di
    pop     si
    pop     cx
    inc     si
    loop    .search_loop

    ; Not found
    clc
    jmp     .ret

.found:
    pop     di
    pop     si
    pop     cx
    stc

.ret:
    pop     di
    pop     si
    pop     cx
    pop     ax
    ret

;---------------------------------------
; Get equipment list (INT 11h)
;---------------------------------------
get_equipment:
    push    ax
    push    bx
    push    cx

    mov     ah, 09h
    mov     dx, equip_label
    int     21h

    int     11h             ; Get equipment word
    mov     bx, ax          ; Save it

    ; Print raw value
    call    print_hex_word

    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Interpret flags
    ; Bit 0: Floppy installed
    test    bx, 0001h
    jz      .no_floppy
    mov     ah, 09h
    mov     dx, equip_floppy
    int     21h
.no_floppy:

    ; Bits 1-2: Initial video mode
    mov     ax, bx
    and     ax, 0030h
    shr     ax, 4
    cmp     al, 3
    je      .vga_mono
    cmp     al, 2
    je      .cga_80
    jmp     .other_video
.vga_mono:
    mov     ah, 09h
    mov     dx, equip_mono
    int     21h
    jmp     .check_mouse
.cga_80:
    mov     ah, 09h
    mov     dx, equip_cga
    int     21h
    jmp     .check_mouse
.other_video:

.check_mouse:
    ; Bit 2: PS/2 mouse
    test    bx, 0004h
    jz      .no_mouse
    mov     ah, 09h
    mov     dx, equip_mouse
    int     21h
.no_mouse:

    ; Bits 6-7: Floppy count
    mov     ax, bx
    and     ax, 00C0h
    shr     ax, 6
    inc     ax              ; 00=1 drive, etc.
    push    ax
    mov     ah, 09h
    mov     dx, equip_flp_cnt
    int     21h
    pop     ax
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Bits 9-11: Serial ports
    mov     ax, bx
    and     ax, 0E00h
    shr     ax, 9
    push    ax
    mov     ah, 09h
    mov     dx, equip_serial
    int     21h
    pop     ax
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     ah, 09h
    mov     dx, newline
    int     21h

    ; Bits 14-15: Parallel ports
    mov     ax, bx
    and     ax, 0C000h
    shr     ax, 14
    push    ax
    mov     ah, 09h
    mov     dx, equip_parallel
    int     21h
    pop     ax
    add     al, '0'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     ah, 09h
    mov     dx, newline
    int     21h

    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Get conventional memory (INT 12h)
;---------------------------------------
get_conv_memory:
    push    ax

    mov     ah, 09h
    mov     dx, conv_label
    int     21h

    int     12h             ; Get memory in KB
    call    print_decimal

    mov     ah, 09h
    mov     dx, kb_suffix
    int     21h

    pop     ax
    ret

;---------------------------------------
; Get extended memory (INT 15h, AH=88h)
;---------------------------------------
get_ext_memory:
    push    ax

    mov     ah, 09h
    mov     dx, ext_label
    int     21h

    mov     ah, 88h
    int     15h
    jc      .no_ext

    cmp     ax, 0
    je      .no_ext

    call    print_decimal

    mov     ah, 09h
    mov     dx, kb_suffix
    int     21h
    jmp     .done

.no_ext:
    mov     ah, 09h
    mov     dx, none_msg
    int     21h

.done:
    pop     ax
    ret

;---------------------------------------
; Detect CPU type
;---------------------------------------
detect_cpu:
    push    ax
    push    bx
    push    cx

    mov     ah, 09h
    mov     dx, cpu_label
    int     21h

    ; Test for 8086/8088 vs 286+
    ; Try to push SP - 8086 pushes SP after decrement
    push    sp
    pop     ax
    cmp     ax, sp
    jne     .is_8086

    ; Test for 286 vs 386+
    ; Try to set NT flag (bit 14) - only works on 386+
    pushf
    pop     ax
    or      ax, 4000h       ; Set NT bit
    push    ax
    popf
    pushf
    pop     ax
    test    ax, 4000h
    jz      .is_286

    ; Test for 386 vs 486+
    ; Try to flip AC bit (bit 18) - only works on 486+
    pushfd
    pop     eax
    mov     ebx, eax
    xor     eax, 40000h     ; Flip AC bit
    push    eax
    popfd
    pushfd
    pop     eax
    cmp     eax, ebx
    je      .is_386

    ; Test for 486 vs Pentium+
    ; Try CPUID - only works on Pentium+
    pushfd
    pop     eax
    mov     ebx, eax
    xor     eax, 200000h    ; Flip ID bit
    push    eax
    popfd
    pushfd
    pop     eax
    cmp     eax, ebx
    je      .is_486

    ; Has CPUID - Pentium or better
    jmp     .has_cpuid

.is_8086:
    mov     ah, 09h
    mov     dx, cpu_8086
    int     21h
    jmp     .cpu_done

.is_286:
    mov     ah, 09h
    mov     dx, cpu_286
    int     21h
    jmp     .cpu_done

.is_386:
    mov     ah, 09h
    mov     dx, cpu_386
    int     21h
    jmp     .cpu_done

.is_486:
    mov     ah, 09h
    mov     dx, cpu_486
    int     21h
    jmp     .cpu_done

.has_cpuid:
    ; Get CPU vendor string
    xor     eax, eax
    cpuid
    mov     [cpu_vendor], ebx
    mov     [cpu_vendor+4], edx
    mov     [cpu_vendor+8], ecx
    mov     byte [cpu_vendor+12], 0

    ; Get CPU family/model
    mov     eax, 1
    cpuid
    mov     [cpu_info], eax

    ; Print vendor
    mov     ah, 09h
    mov     dx, cpu_vendor
    int     21h

    mov     ah, 09h
    mov     dx, cpu_family_lbl
    int     21h

    ; Extract family (bits 8-11)
    mov     eax, [cpu_info]
    shr     eax, 8
    and     ax, 0Fh
    call    print_decimal

    mov     ah, 09h
    mov     dx, cpu_model_lbl
    int     21h

    ; Extract model (bits 4-7)
    mov     eax, [cpu_info]
    shr     eax, 4
    and     ax, 0Fh
    call    print_decimal

    mov     ah, 09h
    mov     dx, newline
    int     21h

.cpu_done:
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Detect ISA devices by probing I/O ports
;---------------------------------------
detect_isa_devices:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Check for NE2000 (common addresses: 300h, 320h, 340h, 360h)
    mov     ah, 09h
    mov     dx, isa_ne2000_lbl
    int     21h

    mov     dx, 300h
    call    probe_ne2000
    jc      .found_ne2000_300

    mov     dx, 320h
    call    probe_ne2000
    jc      .found_ne2000_320

    mov     dx, 340h
    call    probe_ne2000
    jc      .found_ne2000_340

    mov     dx, 360h
    call    probe_ne2000
    jc      .found_ne2000_360

    mov     ah, 09h
    mov     dx, not_found
    int     21h
    jmp     .check_3c509

.found_ne2000_300:
    mov     ah, 09h
    mov     dx, found_300
    int     21h
    jmp     .check_3c509
.found_ne2000_320:
    mov     ah, 09h
    mov     dx, found_320
    int     21h
    jmp     .check_3c509
.found_ne2000_340:
    mov     ah, 09h
    mov     dx, found_340
    int     21h
    jmp     .check_3c509
.found_ne2000_360:
    mov     ah, 09h
    mov     dx, found_360
    int     21h

.check_3c509:
    ; Check for 3Com 3C509 (uses ID port at 110h)
    mov     ah, 09h
    mov     dx, isa_3c509_lbl
    int     21h

    call    probe_3c509
    jc      .found_3c509

    mov     ah, 09h
    mov     dx, not_found
    int     21h
    jmp     .check_sound

.found_3c509:
    mov     ah, 09h
    mov     dx, found_msg
    int     21h

.check_sound:
    ; Check for Sound Blaster (220h, 240h)
    mov     ah, 09h
    mov     dx, isa_sb_lbl
    int     21h

    mov     dx, 220h
    call    probe_soundblaster
    jc      .found_sb_220

    mov     dx, 240h
    call    probe_soundblaster
    jc      .found_sb_240

    mov     ah, 09h
    mov     dx, not_found
    int     21h
    jmp     .check_com

.found_sb_220:
    mov     ah, 09h
    mov     dx, found_220
    int     21h
    jmp     .check_com
.found_sb_240:
    mov     ah, 09h
    mov     dx, found_240
    int     21h

.check_com:
    ; Check COM ports (3F8, 2F8, 3E8, 2E8)
    mov     ah, 09h
    mov     dx, isa_com_lbl
    int     21h

    mov     cx, 0           ; Count found ports

    ; COM1 at 3F8
    mov     dx, 3F8h
    call    probe_uart
    jnc     .no_com1
    inc     cx
    push    cx
    mov     ah, 09h
    mov     dx, com1_found
    int     21h
    pop     cx
.no_com1:

    ; COM2 at 2F8
    mov     dx, 2F8h
    call    probe_uart
    jnc     .no_com2
    inc     cx
    push    cx
    mov     ah, 09h
    mov     dx, com2_found
    int     21h
    pop     cx
.no_com2:

    ; COM3 at 3E8
    mov     dx, 3E8h
    call    probe_uart
    jnc     .no_com3
    inc     cx
    push    cx
    mov     ah, 09h
    mov     dx, com3_found
    int     21h
    pop     cx
.no_com3:

    ; COM4 at 2E8
    mov     dx, 2E8h
    call    probe_uart
    jnc     .no_com4
    inc     cx
    push    cx
    mov     ah, 09h
    mov     dx, com4_found
    int     21h
    pop     cx
.no_com4:

    cmp     cx, 0
    jne     .com_done
    mov     ah, 09h
    mov     dx, none_msg
    int     21h

.com_done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; Probe for NE2000 at port DX
; Returns CF set if found
probe_ne2000:
    push    ax
    push    dx

    ; NE2000 reset port is base + 1Fh
    add     dx, 1Fh
    in      al, dx
    out     dx, al          ; Reset

    ; Small delay
    mov     cx, 1000
.delay:
    loop    .delay

    ; Read back reset register - should be 52h or similar
    sub     dx, 1Fh         ; Back to base
    in      al, dx
    cmp     al, 0FFh        ; If all 1s, nothing there
    je      .not_found
    cmp     al, 0           ; If all 0s, nothing there
    je      .not_found

    ; Check for DP8390 signature pattern
    add     dx, 0Dh         ; RBCR0
    in      al, dx
    cmp     al, 0FFh
    je      .not_found

    stc                     ; Found
    jmp     .done

.not_found:
    clc

.done:
    pop     dx
    pop     ax
    ret

; Probe for 3C509 (uses ID port sequence)
probe_3c509:
    push    ax
    push    cx
    push    dx

    ; 3C509 ID port at 110h
    mov     dx, 110h

    ; Send ID sequence
    xor     al, al
    out     dx, al
    out     dx, al

    mov     al, 0FFh
    out     dx, al

    ; Read back
    in      al, dx
    cmp     al, 0FFh
    je      .not_found

    ; Check for 3Com signature
    and     al, 0F0h
    cmp     al, 60h
    jne     .not_found

    stc
    jmp     .done

.not_found:
    clc

.done:
    pop     dx
    pop     cx
    pop     ax
    ret

; Probe for Sound Blaster at port DX
probe_soundblaster:
    push    ax
    push    cx
    push    dx

    ; DSP reset port is base + 6
    add     dx, 6
    mov     al, 1
    out     dx, al          ; Start reset

    ; Delay
    mov     cx, 100
.delay1:
    loop    .delay1

    xor     al, al
    out     dx, al          ; End reset

    ; Delay
    mov     cx, 1000
.delay2:
    loop    .delay2

    ; Read data available port (base + 0Eh)
    mov     dx, word [esp+2]
    add     dx, 0Eh
    mov     cx, 100
.wait_data:
    in      al, dx
    test    al, 80h
    jnz     .data_ready
    loop    .wait_data
    jmp     .not_found

.data_ready:
    ; Read data port (base + 0Ah)
    mov     dx, word [esp+2]
    add     dx, 0Ah
    in      al, dx
    cmp     al, 0AAh        ; DSP ready signature
    jne     .not_found

    stc
    jmp     .done

.not_found:
    clc

.done:
    pop     dx
    pop     cx
    pop     ax
    ret

; Probe for UART at port DX
probe_uart:
    push    ax
    push    bx
    push    dx

    ; Save base port
    mov     bx, dx

    ; Check scratch register (base + 7)
    add     dx, 7
    mov     al, 55h
    out     dx, al
    in      al, dx
    cmp     al, 55h
    jne     .not_found

    mov     al, 0AAh
    out     dx, al
    in      al, dx
    cmp     al, 0AAh
    jne     .not_found

    ; Check for 16550A FIFO
    mov     dx, bx
    add     dx, 2           ; FCR/IIR
    mov     al, 0C1h        ; Enable FIFO
    out     dx, al
    in      al, dx
    and     al, 0C0h
    cmp     al, 0C0h
    jne     .is_8250

    mov     byte [uart_type], '5'  ; 16550
    jmp     .found

.is_8250:
    mov     byte [uart_type], '0'  ; 8250

.found:
    stc
    jmp     .done

.not_found:
    clc

.done:
    pop     dx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Get serial numbers from BIOS tables
;---------------------------------------
get_serial_numbers:
    push    ax
    push    bx
    push    cx
    push    si
    push    di
    push    es

    ; Look for DMI/SMBIOS anchor at F000:0 - F000:FFF0
    ; Anchor string is "_SM_" or "_DMI_"
    mov     ax, 0F000h
    mov     es, ax
    xor     si, si
    mov     cx, 0FFF0h

.search_dmi:
    cmp     dword [es:si], '_SM_'
    je      .found_smbios
    cmp     dword [es:si], '_DMI'
    je      .found_dmi
    inc     si
    loop    .search_dmi

    ; Not found - try E000 segment (some BIOSes)
    mov     ax, 0E000h
    mov     es, ax
    xor     si, si
    mov     cx, 0FFF0h

.search_e000:
    cmp     dword [es:si], '_SM_'
    je      .found_smbios
    cmp     dword [es:si], '_DMI'
    je      .found_dmi
    inc     si
    loop    .search_e000

    mov     ah, 09h
    mov     dx, no_dmi_msg
    int     21h
    jmp     .done

.found_smbios:
    mov     ah, 09h
    mov     dx, smbios_found
    int     21h

    ; SMBIOS entry point found at ES:SI
    ; Structure table address at offset 18h
    mov     di, [es:si+18h]
    mov     ax, [es:si+1Ah]
    mov     es, ax

    ; Parse SMBIOS structures
    call    parse_smbios_structures
    jmp     .done

.found_dmi:
    mov     ah, 09h
    mov     dx, dmi_found
    int     21h

.done:
    pop     es
    pop     di
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

; Parse SMBIOS structures looking for Type 1 (System Info)
parse_smbios_structures:
    push    ax
    push    bx
    push    cx
    push    si

    xor     si, si
    mov     cx, 20          ; Max structures to check

.parse_loop:
    ; Type at offset 0
    mov     al, [es:si]
    cmp     al, 127         ; End marker
    je      .parse_done
    cmp     al, 1           ; System Information
    je      .found_sys_info

    ; Skip to next structure
    ; Length at offset 1
    movzx   bx, byte [es:si+1]
    add     si, bx

    ; Skip strings (double null terminated)
.skip_strings:
    cmp     byte [es:si], 0
    jne     .not_end
    cmp     byte [es:si+1], 0
    je      .end_strings
.not_end:
    inc     si
    jmp     .skip_strings
.end_strings:
    add     si, 2

    loop    .parse_loop
    jmp     .parse_done

.found_sys_info:
    ; Type 1 structure found
    mov     ah, 09h
    mov     dx, sys_mfr_lbl
    int     21h

    ; Manufacturer string index at offset 4
    movzx   ax, byte [es:si+4]
    call    print_smbios_string

    mov     ah, 09h
    mov     dx, sys_prod_lbl
    int     21h

    ; Product string index at offset 5
    movzx   ax, byte [es:si+5]
    call    print_smbios_string

    mov     ah, 09h
    mov     dx, sys_serial_lbl
    int     21h

    ; Serial string index at offset 7
    movzx   ax, byte [es:si+7]
    call    print_smbios_string

.parse_done:
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret

; Print SMBIOS string number AX from current structure at ES:SI
print_smbios_string:
    push    bx
    push    cx
    push    si

    cmp     ax, 0
    je      .empty_string

    ; Skip to string area
    movzx   bx, byte [es:si+1]
    add     si, bx

    ; Find string number AX
    mov     cx, ax
    dec     cx
    jcxz    .print_str

.skip_str:
    cmp     byte [es:si], 0
    je      .next_str
    inc     si
    jmp     .skip_str
.next_str:
    inc     si
    loop    .skip_str

.print_str:
    ; Print until null
.print_char:
    mov     al, [es:si]
    cmp     al, 0
    je      .print_done
    mov     dl, al
    mov     ah, 02h
    int     21h
    inc     si
    jmp     .print_char

.empty_string:
    mov     ah, 09h
    mov     dx, na_msg
    int     21h

.print_done:
    mov     ah, 09h
    mov     dx, newline
    int     21h

    pop     si
    pop     cx
    pop     bx
    ret

;---------------------------------------
; Dump CMOS/RTC data
;---------------------------------------
dump_cmos:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     ah, 09h
    mov     dx, cmos_dump_lbl
    int     21h

    ; Read and display CMOS bytes 0-3Fh
    xor     bx, bx          ; CMOS address

.dump_row:
    ; Print address
    mov     ax, bx
    call    print_hex_byte
    mov     dl, ':'
    mov     ah, 02h
    int     21h
    mov     dl, ' '
    int     21h

    ; Print 16 bytes
    mov     cx, 16
.dump_col:
    mov     al, bl
    out     70h, al
    in      al, 71h
    call    print_hex_byte
    mov     dl, ' '
    mov     ah, 02h
    int     21h
    inc     bl
    loop    .dump_col

    mov     ah, 09h
    mov     dx, newline
    int     21h

    cmp     bl, 40h
    jb      .dump_row

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------
; Utility: Print AX as decimal
;---------------------------------------
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

;---------------------------------------
; Utility: Print AX as hex word
;---------------------------------------
print_hex_word:
    push    ax
    mov     al, ah
    call    print_hex_byte
    pop     ax
    call    print_hex_byte
    ret

;---------------------------------------
; Utility: Print AL as hex byte
;---------------------------------------
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

    pop     bx
    push    bx
    mov     al, ah
    and     al, 0Fh
    mov     bx, hex_chars
    xlat
    mov     dl, al
    mov     ah, 02h
    int     21h

    pop     bx
    pop     ax
    ret

;---------------------------------------
; Data section
;---------------------------------------
section .data

header_msg:
    db 13, 10
    db '======================================================', 13, 10
    db '  RustChain Hardware Scraper v1.0', 13, 10
    db '  Proof of Antiquity (RIP-PoA) Fingerprinting', 13, 10
    db '======================================================', 13, 10
    db '$'

bios_header:
    db 13, 10, '--- BIOS Information ---', 13, 10, '$'

sys_header:
    db 13, 10, '--- System Information ---', 13, 10, '$'

cpu_header:
    db 13, 10, '--- CPU Detection ---', 13, 10, '$'

isa_header:
    db 13, 10, '--- ISA Bus Detection ---', 13, 10, '$'

serial_header:
    db 13, 10, '--- Serial Numbers (DMI/SMBIOS) ---', 13, 10, '$'

cmos_header:
    db 13, 10, '--- CMOS/RTC Data ---', 13, 10, '$'

date_label:     db '  BIOS Date: $'
sig_label:      db '  BIOS Signature: $'
vendor_label:   db '  BIOS Vendor: $'

sig_pc:         db ' (Original PC)', 13, 10, '$'
sig_xt:         db ' (PC/XT)', 13, 10, '$'
sig_pcjr:       db ' (PCjr)', 13, 10, '$'
sig_at:         db ' (PC/AT)', 13, 10, '$'
sig_xt_enh:     db ' (XT Enhanced)', 13, 10, '$'
sig_ps2_30:     db ' (PS/2 Model 30)', 13, 10, '$'
sig_pc_conv:    db ' (PC Convertible)', 13, 10, '$'
sig_ps2_80:     db ' (PS/2 Model 80)', 13, 10, '$'
sig_unknown:    db ' (Unknown)', 13, 10, '$'

str_ami:        db 'AMI', 0
str_award:      db 'Award', 0
str_phoenix:    db 'Phoenix', 0
str_ibm:        db 'IBM', 0
str_compaq:     db 'COMPAQ', 0
str_dell:       db 'Dell', 0

vendor_ami:     db 'AMI (American Megatrends)', 13, 10, '$'
vendor_award:   db 'Award Software', 13, 10, '$'
vendor_phoenix: db 'Phoenix Technologies', 13, 10, '$'
vendor_ibm:     db 'IBM', 13, 10, '$'
vendor_compaq:  db 'Compaq', 13, 10, '$'
vendor_dell:    db 'Dell', 13, 10, '$'
vendor_unknown: db 'Unknown', 13, 10, '$'

equip_label:    db '  Equipment Word: $'
equip_floppy:   db '    - Floppy drive(s) present', 13, 10, '$'
equip_mono:     db '    - Monochrome video', 13, 10, '$'
equip_cga:      db '    - CGA 80-column video', 13, 10, '$'
equip_mouse:    db '    - PS/2 mouse present', 13, 10, '$'
equip_flp_cnt:  db '    - Floppy drives: $'
equip_serial:   db '    - Serial ports: $'
equip_parallel: db '    - Parallel ports: $'

conv_label:     db '  Conventional Memory: $'
ext_label:      db '  Extended Memory: $'
kb_suffix:      db ' KB', 13, 10, '$'

cpu_label:      db '  CPU Type: $'
cpu_8086:       db '8086/8088', 13, 10, '$'
cpu_286:        db '80286', 13, 10, '$'
cpu_386:        db '80386', 13, 10, '$'
cpu_486:        db '80486', 13, 10, '$'
cpu_family_lbl: db ', Family: $'
cpu_model_lbl:  db ', Model: $'

isa_ne2000_lbl: db '  NE2000 compatible: $'
isa_3c509_lbl:  db '  3Com 3C509: $'
isa_sb_lbl:     db '  Sound Blaster: $'
isa_com_lbl:    db '  COM ports:', 13, 10, '$'

found_300:      db 'Found at 300h', 13, 10, '$'
found_320:      db 'Found at 320h', 13, 10, '$'
found_340:      db 'Found at 340h', 13, 10, '$'
found_360:      db 'Found at 360h', 13, 10, '$'
found_220:      db 'Found at 220h', 13, 10, '$'
found_240:      db 'Found at 240h', 13, 10, '$'
found_msg:      db 'Found', 13, 10, '$'
not_found:      db 'Not found', 13, 10, '$'
none_msg:       db 'None', 13, 10, '$'

com1_found:     db '    COM1 (3F8h)', 13, 10, '$'
com2_found:     db '    COM2 (2F8h)', 13, 10, '$'
com3_found:     db '    COM3 (3E8h)', 13, 10, '$'
com4_found:     db '    COM4 (2E8h)', 13, 10, '$'

no_dmi_msg:     db '  No DMI/SMBIOS tables found', 13, 10, '$'
smbios_found:   db '  SMBIOS found', 13, 10, '$'
dmi_found:      db '  DMI found', 13, 10, '$'
sys_mfr_lbl:    db '  Manufacturer: $'
sys_prod_lbl:   db '  Product: $'
sys_serial_lbl: db '  Serial Number: $'
na_msg:         db 'N/A$'

cmos_dump_lbl:  db '  First 64 bytes:', 13, 10, '$'

done_msg:
    db 13, 10
    db '======================================================', 13, 10
    db '  Hardware scan complete. Press any key to exit.', 13, 10
    db '======================================================', 13, 10
    db '$'

newline:        db 13, 10, '$'
hex_chars:      db '0123456789ABCDEF'

section .bss

cpu_vendor:     resb 16
cpu_info:       resd 1
uart_type:      resb 1
