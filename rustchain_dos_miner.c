/*
 * RUSTCHAIN DOS MINER - "Fossil Edition"
 * For 8086/286/386/486/Pentium DOS systems
 * Auto-wallet generation + attestation upload
 *
 * Compile with DJGPP: gcc -o miner.exe rustchain_dos_miner.c -lwatt
 * Requires: Packet driver + Watt-32 library
 *
 * Dev Fee: 0.001 RTC/epoch -> founder_dev_fund
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef __DJGPP__
#include <dos.h>
#include <dpmi.h>
#include <go32.h>
#include <sys/farptr.h>
#include <tcp.h>  /* Watt-32 */
#else
#include <dos.h>
#include <bios.h>
#include <conio.h>
#endif

#define NODE_HOST "50.28.86.131"
#define NODE_PORT 8088
#define BLOCK_TIME 600
#define DEV_FEE "0.001"
#define DEV_WALLET "founder_dev_fund"
#define TIMER_SAMPLES 32
#define WALLET_FILE "WALLET.TXT"
#define CONFIG_FILE "MINER.CFG"

/* ============================================
   ENTROPY STRUCTURES
   ============================================ */

typedef struct {
    char bios_date[9];
    unsigned char bios_model;
    char cpu_vendor[13];
    unsigned long cpu_signature;
    unsigned int conv_memory;
    unsigned int ext_memory;
    unsigned int timer_samples[TIMER_SAMPLES];
    unsigned char rtc_time[3];
    unsigned char video_mode;
    unsigned char has_vga;
    unsigned char hash[32];
} DosEntropy;

typedef struct {
    char wallet_id[48];
    char miner_id[32];
    unsigned long created;
    unsigned char initialized;
} WalletConfig;

/* Global state */
static DosEntropy g_entropy;
static WalletConfig g_wallet;
static int g_network_ok = 0;

/* ============================================
   LOW-LEVEL I/O
   ============================================ */

unsigned char port_in(unsigned port) {
#ifdef __DJGPP__
    unsigned char result;
    __asm__ __volatile__("inb %1, %0" : "=a"(result) : "d"((unsigned short)port));
    return result;
#else
    return inportb(port);
#endif
}

void port_out(unsigned port, unsigned char value) {
#ifdef __DJGPP__
    __asm__ __volatile__("outb %0, %1" : : "a"(value), "d"((unsigned short)port));
#else
    outportb(port, value);
#endif
}

/* ============================================
   ENTROPY COLLECTION
   ============================================ */

void collect_bios_info(void) {
#ifdef __DJGPP__
    int i;
    /* Read BIOS date from F000:FFF5 */
    for (i = 0; i < 8; i++) {
        g_entropy.bios_date[i] = _farpeekb(_dos_ds, 0xFFFF5 + i);
    }
    g_entropy.bios_date[8] = '\0';
    g_entropy.bios_model = _farpeekb(_dos_ds, 0xFFFFE);
#else
    unsigned char far *bios = (unsigned char far *)0xF000FFF5L;
    int i;
    for (i = 0; i < 8; i++) {
        g_entropy.bios_date[i] = bios[i];
    }
    g_entropy.bios_date[8] = '\0';
    g_entropy.bios_model = *((unsigned char far *)0xF000FFFEL);
#endif
}

void detect_cpu(void) {
    int has_cpuid = 0;
    unsigned long eax, ebx, ecx, edx;

#ifdef __DJGPP__
    /* Check for CPUID support */
    __asm__ __volatile__(
        "pushfl\n"
        "popl %%eax\n"
        "movl %%eax, %%ebx\n"
        "xorl $0x200000, %%eax\n"
        "pushl %%eax\n"
        "popfl\n"
        "pushfl\n"
        "popl %%eax\n"
        "xorl %%ebx, %%eax\n"
        "andl $0x200000, %%eax\n"
        : "=a"(has_cpuid) : : "ebx"
    );

    if (has_cpuid) {
        __asm__ __volatile__(
            "xorl %%eax, %%eax\n"
            "cpuid\n"
            : "=b"(ebx), "=c"(ecx), "=d"(edx) : : "eax"
        );
        memcpy(g_entropy.cpu_vendor, &ebx, 4);
        memcpy(g_entropy.cpu_vendor + 4, &edx, 4);
        memcpy(g_entropy.cpu_vendor + 8, &ecx, 4);
        g_entropy.cpu_vendor[12] = '\0';

        __asm__ __volatile__(
            "movl $1, %%eax\n"
            "cpuid\n"
            : "=a"(eax) : : "ebx", "ecx", "edx"
        );
        g_entropy.cpu_signature = eax;
    } else
#endif
    {
        strcpy(g_entropy.cpu_vendor, "DOS-ANCIENT");
        g_entropy.cpu_signature = 0x386;
    }
}

void collect_memory_info(void) {
    union REGS regs;

    /* INT 12h - Conventional memory */
    int86(0x12, &regs, &regs);
    g_entropy.conv_memory = regs.x.ax;

    /* INT 15h, AH=88h - Extended memory */
    regs.h.ah = 0x88;
    int86(0x15, &regs, &regs);
    g_entropy.ext_memory = (regs.x.cflag) ? 0 : regs.x.ax;
}

void collect_timer_entropy(void) {
    int i, j;
    for (i = 0; i < TIMER_SAMPLES; i++) {
        port_out(0x43, 0x00);  /* Latch timer 0 */
        g_entropy.timer_samples[i] = port_in(0x40);
        g_entropy.timer_samples[i] |= (unsigned int)port_in(0x40) << 8;
        for (j = 0; j < 100; j++) { /* Small delay */ }
    }
}

void collect_rtc(void) {
#ifdef __DJGPP__
    disable();
#else
    _disable();
#endif

    port_out(0x70, 0x00);
    g_entropy.rtc_time[0] = port_in(0x71);
    port_out(0x70, 0x02);
    g_entropy.rtc_time[1] = port_in(0x71);
    port_out(0x70, 0x04);
    g_entropy.rtc_time[2] = port_in(0x71);

#ifdef __DJGPP__
    enable();
#else
    _enable();
#endif
}

void detect_video(void) {
    union REGS regs;

    regs.h.ah = 0x0F;
    int86(0x10, &regs, &regs);
    g_entropy.video_mode = regs.h.al;

    regs.x.ax = 0x1A00;
    int86(0x10, &regs, &regs);
    g_entropy.has_vga = (regs.h.al == 0x1A) ? 1 : 0;
}

/* ============================================
   HASH / WALLET GENERATION
   ============================================ */

/* Simple but effective hash for DOS */
void generate_entropy_hash(void) {
    unsigned long h[4] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476};
    unsigned char *ptr;
    int i, j;

    /* Mix all entropy sources */
    for (i = 0; i < 8; i++) {
        h[0] ^= (unsigned long)g_entropy.bios_date[i] << ((i % 4) * 8);
        h[0] = (h[0] << 5) | (h[0] >> 27);
    }

    h[1] ^= g_entropy.bios_model;
    h[1] ^= g_entropy.cpu_signature;
    h[1] = (h[1] << 7) | (h[1] >> 25);

    for (i = 0; i < TIMER_SAMPLES; i++) {
        h[2] ^= g_entropy.timer_samples[i];
        h[2] = (h[2] << 3) | (h[2] >> 29);
    }

    h[3] ^= ((unsigned long)g_entropy.rtc_time[0] << 16) |
            ((unsigned long)g_entropy.rtc_time[1] << 8) |
            g_entropy.rtc_time[2];
    h[3] ^= ((unsigned long)g_entropy.conv_memory << 16) | g_entropy.ext_memory;

    /* Mix rounds */
    for (j = 0; j < 8; j++) {
        h[0] += h[1]; h[1] = (h[1] << 13) | (h[1] >> 19);
        h[2] += h[3]; h[3] = (h[3] << 17) | (h[3] >> 15);
        h[0] ^= h[3]; h[2] ^= h[1];
    }

    /* Store 32-byte hash */
    for (i = 0; i < 4; i++) {
        ptr = (unsigned char *)&h[i];
        g_entropy.hash[i*4 + 0] = ptr[0];
        g_entropy.hash[i*4 + 1] = ptr[1];
        g_entropy.hash[i*4 + 2] = ptr[2];
        g_entropy.hash[i*4 + 3] = ptr[3];
        /* Duplicate for 32 bytes */
        g_entropy.hash[16 + i*4 + 0] = ptr[0] ^ 0xAA;
        g_entropy.hash[16 + i*4 + 1] = ptr[1] ^ 0x55;
        g_entropy.hash[16 + i*4 + 2] = ptr[2] ^ 0xAA;
        g_entropy.hash[16 + i*4 + 3] = ptr[3] ^ 0x55;
    }
}

void generate_wallet(void) {
    int i;
    static const char hex[] = "0123456789abcdef";

    /* Wallet format: RTC + 40 hex chars from entropy hash */
    strcpy(g_wallet.wallet_id, "RTC");
    for (i = 0; i < 20; i++) {
        g_wallet.wallet_id[3 + i*2] = hex[(g_entropy.hash[i] >> 4) & 0x0F];
        g_wallet.wallet_id[3 + i*2 + 1] = hex[g_entropy.hash[i] & 0x0F];
    }
    g_wallet.wallet_id[43] = '\0';

    /* Miner ID */
    sprintf(g_wallet.miner_id, "DOS-%02X%02X%02X%02X",
            g_entropy.hash[0], g_entropy.hash[1],
            g_entropy.hash[2], g_entropy.hash[3]);

    g_wallet.created = time(NULL);
    g_wallet.initialized = 1;
}

/* ============================================
   FILE I/O
   ============================================ */

int load_wallet(void) {
    FILE *fp = fopen(WALLET_FILE, "r");
    if (!fp) return 0;

    if (fscanf(fp, "%47s", g_wallet.wallet_id) == 1) {
        fscanf(fp, "%31s", g_wallet.miner_id);
        g_wallet.initialized = 1;
        fclose(fp);
        return 1;
    }
    fclose(fp);
    return 0;
}

void save_wallet(void) {
    FILE *fp = fopen(WALLET_FILE, "w");
    if (!fp) {
        printf("ERROR: Cannot save wallet!\n");
        return;
    }

    fprintf(fp, "%s\n", g_wallet.wallet_id);
    fprintf(fp, "%s\n", g_wallet.miner_id);
    fprintf(fp, "# RustChain DOS Miner Wallet\n");
    fprintf(fp, "# Created: %lu\n", g_wallet.created);
    fprintf(fp, "# DO NOT DELETE THIS FILE!\n");
    fclose(fp);

    printf("Wallet saved to %s\n", WALLET_FILE);
}

/* ============================================
   NETWORK (Watt-32)
   ============================================ */

#ifdef __DJGPP__

int init_network(void) {
    if (sock_init()) {
        printf("Network: Watt-32 initialized\n");
        g_network_ok = 1;
        return 1;
    }
    printf("Network: No packet driver found\n");
    g_network_ok = 0;
    return 0;
}

int send_attestation(void) {
    tcp_Socket sock;
    char request[1024];
    char response[512];
    int len;
    unsigned long host;

    if (!g_network_ok) return 0;

    host = resolve(NODE_HOST);
    if (!host) {
        printf("Cannot resolve %s\n", NODE_HOST);
        return 0;
    }

    if (!tcp_open(&sock, 0, host, NODE_PORT, NULL)) {
        printf("Cannot connect to node\n");
        return 0;
    }

    sock_wait_established(&sock, 10, NULL, NULL);

    /* Build JSON attestation */
    sprintf(request,
        "POST /attest/submit HTTP/1.0\r\n"
        "Host: %s\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %d\r\n"
        "\r\n"
        "{"
        "\"miner\":\"%s\","
        "\"miner_id\":\"%s\","
        "\"nonce\":%lu,"
        "\"device\":{"
            "\"arch\":\"dos_ancient\","
            "\"family\":\"x86_16\","
            "\"model\":\"%s\","
            "\"cpu_signature\":\"0x%08lX\","
            "\"bios_date\":\"%s\""
        "},"
        "\"dev_fee\":{"
            "\"enabled\":true,"
            "\"wallet\":\"%s\","
            "\"amount\":%s"
        "}"
        "}",
        NODE_HOST,
        300,  /* Approximate content length */
        g_wallet.wallet_id,
        g_wallet.miner_id,
        time(NULL),
        g_entropy.cpu_vendor,
        g_entropy.cpu_signature,
        g_entropy.bios_date,
        DEV_WALLET,
        DEV_FEE
    );

    sock_puts(&sock, request);
    sock_flush(&sock);

    /* Read response */
    sock_wait_input(&sock, 10, NULL, NULL);
    len = sock_gets(&sock, response, sizeof(response));

    sock_close(&sock);

    if (strstr(response, "200") || strstr(response, "ok")) {
        return 1;
    }

    return 0;

sock_err:
    sock_close(&sock);
    return 0;
}

#else
/* Non-DJGPP stub */
int init_network(void) {
    printf("Network: Offline mode (no Watt-32)\n");
    g_network_ok = 0;
    return 0;
}

int send_attestation(void) {
    return 0;
}
#endif

/* ============================================
   MAIN MINER
   ============================================ */

void print_banner(void) {
    printf("\n");
    printf("======================================================\n");
    printf("  RUSTCHAIN DOS MINER - Fossil Edition\n");
    printf("  For 8086/286/386/486/Pentium\n");
    printf("  \"Every vintage computer has historical potential\"\n");
    printf("======================================================\n");
    printf("  Dev Fee: %s RTC/epoch -> %s\n", DEV_FEE, DEV_WALLET);
    printf("======================================================\n\n");
}

void print_status(void) {
    printf("\n--- MINER STATUS ---\n");
    printf("Wallet:    %s\n", g_wallet.wallet_id);
    printf("Miner ID:  %s\n", g_wallet.miner_id);
    printf("CPU:       %s (0x%08lX)\n", g_entropy.cpu_vendor, g_entropy.cpu_signature);
    printf("BIOS:      %s (Model 0x%02X)\n", g_entropy.bios_date, g_entropy.bios_model);
    printf("Memory:    %uKB conv, %uKB ext\n", g_entropy.conv_memory, g_entropy.ext_memory);
    printf("Video:     Mode 0x%02X, VGA: %s\n", g_entropy.video_mode, g_entropy.has_vga ? "Yes" : "No");
    printf("Network:   %s\n", g_network_ok ? "Online" : "Offline");
    printf("Node:      %s:%d\n", NODE_HOST, NODE_PORT);
    printf("Tier:      ANCIENT (3.5x multiplier!)\n");
    printf("--------------------\n\n");
}

void mining_loop(void) {
    unsigned long next_attest = 0;
    unsigned long now;
    int cycle = 0;

    printf("Starting mining loop (Ctrl+C to exit)...\n\n");

    while (1) {
        now = time(NULL);

        if (now >= next_attest) {
            cycle++;
            printf("[%lu] Cycle %d: Collecting entropy...\n", now, cycle);

            /* Refresh entropy */
            collect_timer_entropy();
            collect_rtc();
            generate_entropy_hash();

            if (g_network_ok) {
                printf("[%lu] Sending attestation to node...\n", now);
                if (send_attestation()) {
                    printf("[%lu] SUCCESS! Attestation accepted.\n", now);
                } else {
                    printf("[%lu] WARN: Attestation failed, will retry.\n", now);
                }
            } else {
                printf("[%lu] Offline mode - saving entropy locally.\n", now);
                /* Could write to ATTEST.TXT for later upload */
            }

            next_attest = now + BLOCK_TIME;
            printf("[%lu] Next attestation in %d seconds.\n\n", now, BLOCK_TIME);
        }

        /* Check for keypress to exit */
        if (kbhit()) {
            int ch = getch();
            if (ch == 27 || ch == 'q' || ch == 'Q') {  /* ESC or Q */
                printf("\nExiting miner...\n");
                break;
            }
            if (ch == 's' || ch == 'S') {  /* Status */
                print_status();
            }
        }

        /* Sleep ~1 second */
        delay(1000);
    }
}

int main(int argc, char *argv[]) {
    print_banner();

    printf("Initializing...\n\n");

    /* Collect hardware entropy */
    printf("[1/5] Collecting BIOS info...\n");
    collect_bios_info();

    printf("[2/5] Detecting CPU...\n");
    detect_cpu();

    printf("[3/5] Reading memory config...\n");
    collect_memory_info();

    printf("[4/5] Collecting timer entropy...\n");
    collect_timer_entropy();
    collect_rtc();
    detect_video();

    printf("[5/5] Generating entropy hash...\n");
    generate_entropy_hash();

    /* Load or generate wallet */
    printf("\nChecking for existing wallet...\n");
    if (load_wallet()) {
        printf("Loaded wallet: %s\n", g_wallet.wallet_id);
    } else {
        printf("No wallet found, generating new wallet...\n");
        generate_wallet();
        save_wallet();
        printf("\n");
        printf("========================================\n");
        printf("  NEW WALLET GENERATED!\n");
        printf("  %s\n", g_wallet.wallet_id);
        printf("========================================\n");
        printf("  SAVE THIS! Copy %s to floppy!\n", WALLET_FILE);
        printf("========================================\n\n");
    }

    /* Initialize network */
    printf("Initializing network...\n");
    init_network();

    /* Show status */
    print_status();

    /* Start mining */
    printf("Press 'S' for status, 'Q' or ESC to quit.\n\n");
    mining_loop();

    printf("\nMiner stopped. Wallet: %s\n", g_wallet.wallet_id);
    return 0;
}
