// Dart Baseline Workload: Native AOT Compiled Performance
void main() {
  int tokenCount = 0;
  for (int iteration = 0; iteration < 16; iteration++) {
    for (int i = 0; i < 65536; i++) {
      int cur = i & 0xFF;
      if (cur == 32 || cur == 10) {
        tokenCount++;
      }
    }
  }
  print("[Dart] Workload Execution Complete. Tokens: $tokenCount");
}