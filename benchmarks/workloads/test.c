// C Baseline Workload: Byte-Stream Buffer Iteration & Token Parsing
// Compiled with: gcc -nostdlib -O3

long sys_write(long fd, const void *buf, long count) {
    long ret;
    __asm__ volatile (
        "syscall"
        : "=a" (ret)
        : "a" (1), "D" (fd), "S" ((long)buf), "d" (count)
        : "rcx", "r11", "memory"
    );
    return ret;
}

void sys_exit(long status) {
    __asm__ volatile (
        "syscall"
        :
        : "a" (60), "D" (status)
        : "rcx", "r11", "memory"
    );
}

int main() {
    unsigned char buffer[65536];
    long token_count = 0;
    
    for (int iteration = 0; iteration < 16; iteration++) {
        for (int i = 0; i < 65536; i++) {
            unsigned char cur = (unsigned char)(i & 0xFF);
            if (cur == 32 || cur == 10) {
                token_count++;
            }
        }
    }

    const char* msg = "[C] Workload Execution Complete.\n";
    sys_write(1, msg, 33);
    sys_exit(0);
    return 0;
}

void _start() {
    main();
}