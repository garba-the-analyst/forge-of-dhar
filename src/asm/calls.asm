; calls.asm - function-call handling (StageAlpha 3)
section .text

emit_call_sequence:
    push r10
    push r9
    push r13
    mov rax, rcx                    ; V0.3.0: resolve callee token by INDEX
    shl rax, 4                      ; (rbx is the DEST token in assign context!)
    lea rax, [token_array + rax]
    mov [ecs_callee_tok], rax
    mov r10, rcx
    inc r10                         ; '('
    xor r9, r9                      ; ordinal
    xor r8, r8                      ; paren depth
.ecs_walk:
    inc r10
    cmp r10, [token_count]
    jge .ecs_done                   ; malformed call: bail out gracefully
    mov rax, r10
    shl rax, 4
    lea r13, [token_array + rax]
    cmp byte [r13], 3
    je .ecs_op
    cmp r9, 6
    jge .ecs_walk                   ; beyond 6 args: parser rejects earlier
    cmp byte [r13], 5
    je .ecs_lit
    cmp byte [r13], 6
    je .ecs_str
    cmp byte [r13], 2               ; must be a real identifier
    jne .ecs_done                   ; anything else -> stop gracefully
    ; identifier arg -> memory LOAD: mov <reg>, qword [name|rbp-N]
    mov rax, r9
    call .ecs_reg_mem_open          ; "    mov <reg>, qword ["
    call write_to_file
    push r9
    mov rdi, [r13 + 8]
    call emit_named_operand
    pop r9
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .ecs_next
.ecs_lit:
    mov rax, r9
    call .ecs_reg_prefix
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .ecs_next
.ecs_str:
    mov rax, r9
    call .ecs_reg_prefix
    call write_to_file
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, r10
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .ecs_next
.ecs_next:
    inc r9
    jmp .ecs_walk
.ecs_op:
    cmp byte [r13 + 1], 2
    jne .ecs_nopen
    inc r8                          ; paren depth (r8 unused otherwise)
    jmp .ecs_walk
.ecs_nopen:
    cmp byte [r13 + 1], 3
    jne .ecs_nclose
    cmp r8, 0
    je .ecs_done                    ; our closing paren
    dec r8
    jmp .ecs_walk
.ecs_nclose:
    jmp .ecs_walk                   ; commas ignored
.ecs_done:
    mov rsi, asm_call
    mov rdx, len_asm_call
    call write_to_file
    mov r13, [ecs_callee_tok]
    mov rdi, [r13 + 8]              ; Phase 1.4: call dhar_<name>
    call emit_mangled_name
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov r11, r10
    pop r13
    pop r9
    pop r10

    ret

; internal: rax = ordinal -> rsi/rdx = "    mov <reg>, qword [" 
.ecs_reg_mem_open:
    cmp rax, 0
    je .ecsm_rdi
    cmp rax, 1
    je .ecsm_rsi
    cmp rax, 2
    je .ecsm_rdx
    cmp rax, 3
    je .ecsm_rcx
    cmp rax, 4
    je .ecsm_r8m
    mov rsi, asm_mov_r9_l
    mov rdx, len_asm_mov_r9_l
    ret
.ecsm_rdi:
    mov rsi, asm_mov_rdi_l
    mov rdx, len_asm_mov_rdi_l
    ret
.ecsm_rsi:
    mov rsi, asm_mov_rsi_l
    mov rdx, len_asm_mov_rsi_l
    ret
.ecsm_rdx:
    mov rsi, asm_mov_rdx_l
    mov rdx, len_asm_mov_rdx_l
    ret
.ecsm_rcx:
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    ret
.ecsm_r8m:
    mov rsi, asm_mov_r8_l
    mov rdx, len_asm_mov_r8_l
    ret

; internal: rax = ordinal -> rsi/rdx = "<reg>, " immediate prefix
.ecs_reg_prefix:
    cmp rax, 0
    je .ecsr_rdi
    cmp rax, 1
    je .ecsr_rsi
    cmp rax, 2
    je .ecsr_rdx
    cmp rax, 3
    je .ecsr_rcx
    cmp rax, 4
    je .ecsr_r8
    mov rsi, asm_mov_r9_lit
    mov rdx, len_asm_mov_r9_lit
    ret
.ecsr_rdi:
    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    ret
.ecsr_rsi:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    ret
.ecsr_rdx:
    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    ret
.ecsr_rcx:
    mov rsi, asm_mov_rcx_lit
    mov rdx, len_asm_mov_rcx_lit
    ret
.ecsr_r8:
    mov rsi, asm_mov_r8_lit
    mov rdx, len_asm_mov_r8_lit
