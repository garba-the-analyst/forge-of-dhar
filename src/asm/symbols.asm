; symbols.asm - symbol-table management (StageAlpha 3)
section .text

; Phase 3 gen_peek: rax = K. Looks at the token K places after rcx (the statement keyword is at rbx).
; Returns rax = 1 and r12 = that token if it exists and sits on the same line as rbx; else rax = 0.
; Preserves everything else (rdx is used and restored).
gen_peek:
    push rdx
    add rax, rcx
    cmp rax, [token_count]
    jae .gp_no
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    jne .gp_no
    mov eax, 1
    pop rdx
    ret
.gp_no:
    xor eax, eax
    pop rdx
    ret

find_symbol:
    push rcx
    push rbx
    push rdi
    push r8
    xor r8, r8                      
.find_loop:
    cmp r8, [symbol_count]
    jge .find_fail
    mov rax, r8
    shl rax, 5                      
    lea rbx, [symbol_table + rax]
    mov rdx, [rbx]                  
    mov rdi, r13                    
    call string_compare
    cmp rax, 1
    je .find_success
    inc r8
    jmp .find_loop
.find_fail:
    mov rax, 0
    jmp .find_exit
.find_success:
    mov rax, 1
    mov rdx, rbx                    
.find_exit:
    pop r8
    pop rdi
    pop rbx
    pop rcx
    ret

check_symbol_collision:
    call find_symbol
    ret

; V0.3.0: redeclaration is an error only within the same owning task
check_symbol_collision_scoped:
    call find_symbol
    cmp rax, 1
    jne .csc_no
    mov eax, [rdx + 20]
    cmp eax, [cur_owner]
    jne .csc_no
    mov rax, 1
    ret
.csc_no:
    mov rax, 0
    ret

; V0.4.1: find symbol by name AND owner (for marking locals in correct task)
find_symbol_scoped:
    push rcx
    push rbx
    push rdi
    push r8
    push r12
    mov r12, rdi                    ; name ptr
    xor r8, r8                      
.fss_loop:
    cmp r8, [symbol_count]
    jge .fss_fail
    mov rax, r8
    shl rax, 5                      
    lea rbx, [symbol_table + rax]
    mov rdx, [rbx]                  
    mov rdi, r12                    
    call string_compare
    cmp rax, 1
    jne .fss_next
    mov eax, [rbx + 20]             ; symbol's owner
    cmp eax, [cur_owner]            ; compare with requested owner
    je .fss_success
    cmp eax, 0                      ; also match globals (owner=0)
    je .fss_success
.fss_next:
    inc r8
    jmp .fss_loop
.fss_fail:
    mov rax, 0
    jmp .fss_exit
.fss_success:
    mov rax, 1
    mov rdx, rbx                    
.fss_exit:
    pop r12
    pop r8
    pop rdi
    pop rbx
    pop rcx
    ret

add_symbol:
    push rax
    push rbx
    push rcx
    push rdx
    push r10
    mov rax, [symbol_count]
    cmp rax, 32768                  ; Phase 1.5b: symbol_table holds 32768
    jae fatal_full
    shl rax, 5                      
    lea rbx, [symbol_table + rax]
    mov [rbx], r13                  
    mov [rbx + 8], r8b              
    mov [rbx + 9], r9b              
    mov [rbx + 10], r15w            
    mov [rbx + 12], r14d            
    ; Tasks (subtype=0) are always global (owner=0)
    cmp r9b, 0
    je .as_task_global
    mov eax, [cur_owner]
    mov [rbx + 20], eax             ; V0.3.0 owner task id
    jmp .as_owner_set
.as_task_global:
    mov qword [rbx + 20], 0         ; tasks are global
    xor eax, eax                    ; ensure eax=0 for local check
.as_owner_set:
    mov dword [rbx + 16], 0         ; Phase 1.1b: dword only — qword here
                                    ; clobbered the owner at [rbx+20] (bytes
                                    ; 20..23), forcing every symbol global and
                                    ; collapsing same-name locals across tasks
                                    ; (sub3 r reused add r at [rbp-24]).
    mov [rbx + 24], r10             
    
    ; V0.4.1: auto-mark task-local variables (owner>0, not task decl)
    test eax, eax
    jz .as_no_local
    cmp byte [rbx + 9], 0           ; task declaration (subtype=0)?
    je .as_no_local
    or byte [rbx + 9], 0x80         ; mark as local (stack-allocated)
    ; Phase 1.6.2: raw[N] locals (not params) reserve ceil(N/8) slots so
    ; in-range indices land inside the frame. local_counts counts SLOTS;
    ; the variable's own offset is the end of its reservation.
    ; NOTE: rdi is caller-owned here (declaration length, used by the
    ; caller after we return), so it is saved/restored around our use.
    mov r10, 1
    cmp byte [rbx + 8], 5           ; parameters keep one slot (raw-param ABI TBD)
    je .as_add_slots
    push rdi                        ; save decl length
    mov rdi, [rbx + 24]             ; array size text (0 for scalars)
    test rdi, rdi
    jz .as_rdi_out
    push rax                        ; task ordinal (parse_uint returns in rax)
    call parse_uint                 ; rax = N (preserves rbx/rdi/rdx)
    mov r10, rax
    pop rax
    add r10, 7
    shr r10, 3                      ; slots = ceil(N/8)
    test r10, r10
    jnz .as_rdi_out
    mov r10, 1                      ; degenerate raw[0]: one slot floor
.as_rdi_out:
    pop rdi                         ; restore decl length
    jmp .as_add_slots
.as_add_slots:
    add [local_counts + rax*8 - 8], r10
    mov r10, [local_counts + rax*8 - 8] ; get current slot count
    shl r10, 3                      ; offset = slots * 8
    mov [rbx + 16], r10d            ; assign stack offset
.as_no_local:
    
    inc qword [symbol_count]
    pop r10
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ==============================================================================
; LEXER SUBROUTINES
; ==============================================================================
