#!/usr/bin/env python3
import sys
import os

# Ensure the 'src' directory is in the module search path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from backend import CodeGeneratorDispatcher, TargetPlatform

def compile_source(source_path, output_dir="build", target=TargetPlatform.LINUX_ELF):
    print(f"[+] Compiling {source_path} for target {target}...")
    
    if not os.path.exists(source_path):
        print(f"[-] Error: Source file {source_path} not found.")
        sys.exit(1)
        
    os.makedirs(output_dir, exist_ok=True)
    
    with open(source_path, "r", encoding="utf-8") as f:
        source_code = f.read()
        
    # Initialize the architecture dispatcher
    dispatcher = CodeGeneratorDispatcher(target=target)
    
    # Configure target-specific assembly payloads
   # Configure target-specific assembly payloads
    if target == TargetPlatform.LINUX_ELF:
        data_asm = 'msg db "[Dhar Linux] Execution Complete", 10\nlen equ $ - msg\n'
        logic_asm = dispatcher.generate_syscall(1, 1, "msg", "len")
        logic_asm += dispatcher.generate_exit(0)
        output_filename = os.path.join(output_dir, "output.asm")
        
    elif target == TargetPlatform.WINDOWS_PE:
        data_asm = 'msg db "[Dhar Windows] Execution Complete", 13, 10, 0\nlen equ $ - msg\n'
        logic_asm = dispatcher.generate_syscall(1, 1, "msg", "len")
        logic_asm += dispatcher.generate_exit(0)
        output_filename = os.path.join(output_dir, "output_win.asm")
        
    else:
        raise ValueError(f"Unsupported target format: {target}")
        
    final_assembly = dispatcher.compile_to_assembly(data_asm, logic_asm)
    
    with open(output_filename, "w", encoding="utf-8") as f:
        f.write(final_assembly)
        
    print(f"[+] Target assembly successfully emitted to {output_filename}")

if __name__ == "__main__":
    target_platform = TargetPlatform.LINUX_ELF
    source_index = 1
    
    if len(sys.argv) > 1 and sys.argv[1] == "--windows":
        target_platform = TargetPlatform.WINDOWS_PE
        source_index = 2
    elif len(sys.argv) > 1 and sys.argv[1] == "linux":
        source_index = 2
        
    source_file = sys.argv[source_index] if len(sys.argv) > source_index else "benchmarks/workloads/test.dhar"
    compile_source(source_file, target=target_platform)