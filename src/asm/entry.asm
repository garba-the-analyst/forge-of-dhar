; ==============================================================================
; THE FORGE OF DHAR (V0.2.3 ARCHITECTURE - Multi-Kernel Target-Triple Dispatch)
; Final Pre-Bootstrapped x86_64 Native Systems Compiler
; V0.2.3: Six-operator conditional engine (== != < > <= >=) with operator-aware
;         jump selection and variable-to-variable memory comparison.
; Author: Abdullahi Baba Garba (Garba the Analyst)
; ==============================================================================

; entry.asm - composition root: %include directives + program entry point only
; (StageAlpha 3: no routine may be defined here beyond the entry point)
section .text
global _start
%include "data.asm"
%include "runtime.asm"
%include "tokenize.asm"
%include "parse.asm"
%include "calls.asm"
%include "symbols.asm"
%include "frames.asm"
%include "codegen.asm"

_start:
    mov rcx, [rsp]                  ; argc
    cmp rcx, 2
    jl .usage
    mov rbx, [rsp + 16]             ; argv[1] is our source file
    xor rsi, rsi
    cmp rcx, 3                      ; target flag argument exists?
    jl .call
    mov rsi, [rsp + 24]             ; argv[2] is target triple flag
.call:
    call bootstrap_init
    call tokenize_source
    call run_parser
    call run_codegen
    mov rax, 60
    xor rdi, rdi
    syscall
.usage:
    mov rax, 1
    mov rdi, 1
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall
