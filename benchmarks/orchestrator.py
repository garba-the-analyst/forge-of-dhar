#!/usr/bin/env python3
import subprocess
import json
import os
import shutil

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR = os.path.join(WORK_DIR, "results")

BENCHMARKS = {
    "Dhar (Native)": {
        "build": "./build/dharc benchmarks/workloads/test.dhar && nasm -f elf64 build/output.asm && ld -m elf_x86_64 -o benchmarks/workloads/dhar_bin build/output.o",
        "exec": "taskset -c 1 ./benchmarks/workloads/dhar_bin"
    },
    "C (Raw -nostdlib)": {
        "build": "gcc -nostdlib -O3 benchmarks/workloads/test.c -o benchmarks/workloads/c_raw",
        "exec": "taskset -c 1 ./benchmarks/workloads/c_raw"
    },
    "C++ (Optimized)": {
        "build": "g++ -O3 benchmarks/workloads/test.cpp -o benchmarks/workloads/cpp_bin",
        "exec": "taskset -c 1 ./benchmarks/workloads/cpp_bin"
    },
    "Rust (Release)": {
        "build": "rustc -C opt-level=3 benchmarks/workloads/test.rs -o benchmarks/workloads/rust_bin",
        "exec": "taskset -c 1 ./benchmarks/workloads/rust_bin"
    },
    "Java (OpenJDK)": {
        "build": "javac benchmarks/workloads/Test.java",
        "exec": "taskset -c 1 java -cp benchmarks/workloads Test"
    },
    "Python": {
        "build": "echo 'No build step'",
        "exec": "taskset -c 1 python3 benchmarks/workloads/test.py"
    },
    "Node.js (JavaScript)": {
        "build": "echo 'No build step'",
        "exec": "taskset -c 1 node benchmarks/workloads/test.js"
    },
    "PHP": {
        "build": "echo 'No build step'",
        "exec": "taskset -c 1 php benchmarks/workloads/test.php"
    }
}
def run_orchestrator():
    os.makedirs(RESULTS_DIR, exist_ok=True)
    print("==================================================")
    print(" DHAR OBJECTIVE COMPARATIVE BENCHMARK HARNESS")
    print("==================================================")

    for lang, config in BENCHMARKS.items():
        print(f"\n[+] Building / Preparing: {lang}")
        build_res = subprocess.run(config["build"], shell=True, capture_output=True, text=True)
        if build_res.returncode != 0:
            print(f"[-] Build failed for {lang}:\n{build_res.stderr}")
            continue

        print(f"[+] Benchmarking via Hyperfine: {lang}")
        json_out = os.path.join(RESULTS_DIR, f"{lang.lower().replace(' ', '_').replace('(', '').replace(')', '').replace('-', '_').replace('+', 'p')}.json")
        
        hyperfine_cmd = f"hyperfine --export-json {json_out} --warmup 3 --runs 100 \"{config['exec']}\""
        subprocess.run(hyperfine_cmd, shell=True)

    print("\n[+] Benchmark execution complete. Results stored in benchmarks/results/")

if __name__ == "__main__":
    run_orchestrator()