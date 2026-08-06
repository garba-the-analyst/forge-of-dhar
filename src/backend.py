#!/usr/bin/env python3
import sys
import os
from enum import Enum

class TargetPlatform(str, Enum):
    LINUX_ELF_X86_64 = "linux-x86_64"
    WINDOWS_PE_X86_64 = "windows-x86_64"
    MACOS_ARM64 = "macos-arm64"
    LINUX_ARM64 = "linux-arm64"
    RISCV_64 = "riscv64"
    WASM_WASI = "wasm32-wasi"

class CodeGeneratorDispatcher:
    def __init__(self, target: TargetPlatform = TargetPlatform.LINUX_ELF_X86_64):
        self.target = target

    def generate_header(self):
        if self.target == TargetPlatform.LINUX_ELF_X86_64:
            return "global _start\nsection .text\n_start:\n"
        
        elif self.target == TargetPlatform.WINDOWS_PE_X86_64:
            return """bits 64
default rel
section .text startup class=CODE
global main
extern ExitProcess
extern GetStdHandle
extern WriteFile

main:
    sub rsp, 40 ; Shadow space allocation
"""
        elif self.target == TargetPlatform.MACOS_ARM64:
            return ".global _main\n.align 2\n_main:\n    stp x29, x30, [sp, #-16]!\n    mov x29, sp\n"
            
        elif self.target == TargetPlatform.LINUX_ARM64:
            return ".global _start\n.align 2\n_start:\n"
            
        elif self.target == TargetPlatform.RISCV_64:
            return ".global _start\n.section .text\n_start:\n"
            
        elif self.target == TargetPlatform.WASM_WASI:
            return "(module\n  (import \"wasi_snapshot_preview1\" \"fd_write\" (func $fd_write (param i32 i32 i32 i32) (result i32)))\n  (import \"wasi_snapshot_preview1\" \"proc_exit\" (func $proc_exit (param i32)))\n  (memory 1)\n  (export \"memory\" (memory 0))\n  (export \"_start\" (func $_start))\n  (func $_start\n"
        else:
            raise ValueError(f"Unsupported compilation target: {self.target}")

    def generate_syscall(self, sys_num, arg1, arg2, arg3):
        if self.target == TargetPlatform.LINUX_ELF_X86_64:
            return f"    mov rax, {sys_num}\n    mov rdi, {arg1}\n    mov rsi, {arg2}\n    mov rdx, {arg3}\n    syscall\n"
            
        elif self.target == TargetPlatform.WINDOWS_PE_X86_64:
            return f"""    mov rcx, -11
    call GetStdHandle
    mov rbx, rax
    mov rcx, rbx
    lea rdx, [{arg2}]
    mov r8, {arg3}
    xor r9, r9
    sub rsp, 32
    call WriteFile
    add rsp, 32\n"""
    
        elif self.target == TargetPlatform.MACOS_ARM64:
            # macOS uses libSystem _write(fd, buf, count)
            return f"    mov x0, #{arg1}\n    adrp x1, {arg2}@PAGE\n    add x1, x1, {arg2}@PAGEOFF\n    mov x2, #{arg3}\n    bl _write\n"
            
        elif self.target == TargetPlatform.LINUX_ARM64:
            # ARM64 Linux sys_write is 64
            sys_num_arm = 64 if sys_num == 1 else sys_num
            return f"    mov x8, #{sys_num_arm}\n    mov x0, #{arg1}\n    ldr x1, ={arg2}\n    mov x2, #{arg3}\n    svc #0\n"
            
        elif self.target == TargetPlatform.RISCV_64:
            sys_num_rv = 64 if sys_num == 1 else sys_num
            return f"    li a7, {sys_num_rv}\n    li a0, {arg1}\n    la a1, {arg2}\n    li a2, {arg3}\n    ecall\n"
            
        elif self.target == TargetPlatform.WASM_WASI:
            return f"    ;; WASI fd_write implementation omitted for text buffer abstraction\n"
            
        else:
            raise NotImplementedError(f"Syscall emission not mapped for {self.target}")

    def generate_exit(self, status):
        if self.target == TargetPlatform.LINUX_ELF_X86_64:
            return f"    mov rax, 60\n    mov rdi, {status}\n    syscall\n"
        elif self.target == TargetPlatform.WINDOWS_PE_X86_64:
            return f"    mov rcx, {status}\n    call ExitProcess\n"
        elif self.target == TargetPlatform.MACOS_ARM64:
            return f"    mov x0, #{status}\n    bl _exit\n"
        elif self.target == TargetPlatform.LINUX_ARM64:
            return f"    mov x8, #93\n    mov x0, #{status}\n    svc #0\n"
        elif self.target == TargetPlatform.RISCV_64:
            return f"    li a7, 93\n    li a0, {status}\n    ecall\n"
        elif self.target == TargetPlatform.WASM_WASI:
            return f"    i32.const {status}\n    call $proc_exit\n  )\n)\n"
        else:
            raise NotImplementedError()

    def compile_to_assembly(self, data_section_asm, core_logic_asm):
        assembly = self.generate_header() + core_logic_asm
        if self.target != TargetPlatform.WASM_WASI:
            assembly += "\nsection .data\n" if "x86_64" in self.target else "\n.data\n"
            assembly += data_section_asm
        return assembly