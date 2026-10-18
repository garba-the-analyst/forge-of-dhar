; frames.asm - stack-frame analysis (StageAlpha 3)
section .text

precompute_frames:
    push rax
    push rcx
    push rdx
    push rbx
    push rdi
    push r12

    mov qword [task_frame_count], 0
    mov qword [scan_in_task], 0
    mov qword [scan_frame_off], 0
    mov dword [scan_task_indent], 0x7FFF
    xor rcx, rcx

.pf_loop:
    cmp rcx, [token_count]
    jge .pf_done
    mov rax, rcx
    shl rax, 4
    lea rbx, [token_array + rax]

    cmp byte [rbx], 1               ; keyword?
    jne .pf_body_check
    cmp byte [rbx + 1], 3           ; 'task'
    je .pf_enter_task
    jmp .pf_body_check

.pf_enter_task:
    mov rax, [task_frame_count]
    inc rax
    mov [task_frame_count], rax
    mov [scan_task_id], rax
    mov qword [scan_frame_off], 0
    movzx edx, word [rbx + 2]
    mov [scan_task_indent], edx

    ; map parameters until signature-closing ':' (paren-depth aware),
    ; THEN arm the body scanner so signature tokens don't exit it.
    mov r12, rcx
    xor r8, r8                      ; paren depth
.pf_paramwalk:
    inc r12
    cmp r12, [token_count]
    jge .pf_next
    mov rax, r12
    shl rax, 4
    lea rdi, [token_array + rax]
    cmp byte [rdi], 3               ; operator
    je .pf_pw_op
    cmp byte [rdi], 2               ; parameter identifier
    jne .pf_paramwalk
    cmp r8, 1                       ; only top-level parens are params
    jne .pf_paramwalk
    push rdi
    mov rdi, [rdi + 8]              ; name string
    call pf_mark_local
    pop rdi
    jmp .pf_paramwalk
.pf_pw_op:
    cmp byte [rdi + 1], 2           ; '('
    jne .pf_pw_not_open
    inc r8
    jmp .pf_paramwalk
.pf_pw_not_open:
    cmp byte [rdi + 1], 3           ; ')'
    jne .pf_pw_not_close
    dec r8
    jmp .pf_paramwalk
.pf_pw_not_close:
    cmp byte [rdi + 1], 1           ; ':' at depth 0 closes signature
    jne .pf_paramwalk
    cmp r8, 0
    jne .pf_paramwalk
    mov qword [scan_in_task], 1     ; arm body scanning HERE
    mov rcx, r12                    ; resume main scan after signature
    jmp .pf_next

.pf_body_check:
    cmp qword [scan_in_task], 0
    je .pf_next
    movzx eax, word [rbx + 2]
    cmp eax, [scan_task_indent]
    jle .pf_exit_task
    cmp byte [rbx], 1
    jne .pf_next
    cmp byte [rbx + 1], 1           ; lock
    je .pf_alloc_local
    cmp byte [rbx + 1], 2           ; flux
    je .pf_alloc_local
    cmp byte [rbx + 1], 13          ; Phase 1.6.2: scan slots its bound var
    je .pf_alloc_scan
    jmp .pf_next

.pf_exit_task:
    mov qword [scan_in_task], 0
    jmp .pf_next

.pf_alloc_local:
    ; name lives in the token AFTER the lock/flux keyword
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .pf_next
    shl rax, 4
    lea rdi, [token_array + rax]
    mov rdi, [rdi + 8]
    call pf_mark_local
    jmp .pf_next
.pf_alloc_scan:
    ; Phase 1.6.2: slot the scan bound var (token after scan) and count
    ; one hidden counter slot for this task's scan.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .pf_next
    shl rax, 4
    lea rdi, [token_array + rax]
    mov rdi, [rdi + 8]
    call pf_mark_local
    mov rax, [scan_task_id]
    inc qword [scan_ctr_total + rax*8 - 8]
.pf_next:
    inc rcx
    jmp .pf_loop

.pf_done:
    pop r12

    pop rdi
    pop rbx
    pop rdx
    pop rcx
    pop rax


    ret

; --- helper: rdi = identifier string -> flag symbol local, assign slot ---
; Uses scan_task_id as owner to find the correct symbol in multi-task scope
pf_mark_local:
    push rax
    push rdx
    push rdi
    push rcx
    push r13
    push r14
    mov r14, [scan_task_id]         ; current task owner
    mov [cur_owner], r14            ; set for scoped find
    call find_symbol_scoped         ; rdi already has name ptr
    cmp rax, 1
    jne .pml_exit
    ; Skip if already has offset assigned (e.g., parameters handled in add_symbol)
    cmp dword [rdx + 16], 0
    jne .pml_exit
    or byte [rdx + 9], 0x80         ; local flag = subtype bit7
    inc qword [scan_frame_off]
    mov rax, [scan_frame_off]
    shl rax, 3                      ; bytes used so far
    mov [rdx + 16], eax             ; positive distance below rbp (32-bit)
    add rax, 15
    and rax, -16                    ; pad frame to 16 bytes
    mov rdx, r14
    mov [frame_offsets + rdx*8 - 8], rax
.pml_exit:
    pop r14
    pop r13
    pop rcx
    pop rdi
    pop rdx
    pop rax
    ret

; ------------------------------------------------------------------------------
; Phase 1.4 emit_mangled_name:
;   rdi = identifier string. Writes dhar_<name>. Preserves rax/rdi/rsi/rdx
;   and touches nothing else (safe anywhere a plain name was written).
; ------------------------------------------------------------------------------
