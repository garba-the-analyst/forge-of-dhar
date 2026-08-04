// C++ Baseline Workload: High-Performance Compiled Loop
#include <iostream>

int main() {
    long token_count = 0;
    for (int iteration = 0; iteration < 16; iteration++) {
        for (int i = 0; i < 65536; i++) {
            unsigned char cur = (unsigned char)(i & 0xFF);
            if (cur == 32 || cur == 10) {
                token_count++;
            }
        }
    }
    std::cout << "[C++] Workload Execution Complete. Tokens: " << token_count << std::endl;
    return 0;
}