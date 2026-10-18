; runtime.asm - minimal runtime support, error reporting (StageAlpha 3)
section .text

bootstrap_init:                     ; rbx = argv[1] source path, rsi = argv[2] or 0

    ; --- TARGET TRIPLE PARSING ---
    mov qword [target_os_flag], 0   ; Default to Linux ELF
    test rsi, rsi                   ; Check if target flag argument exists
    jz .init_compiler_state

    mov r13, rsi                    ; argv[2] is target triple flag
    
    mov rdi, r13
    mov rdx, str_target_windows
    call string_compare
    cmp rax, 1
    je .set_target_windows

    mov rdi, r13
    mov rdx, str_target_wasi
    call string_compare
    cmp rax, 1
    je .set_target_wasi

    jmp .init_compiler_state

.set_target_windows:
    mov qword [target_os_flag], 1
    jmp .init_compiler_state

.set_target_wasi:
    mov qword [target_os_flag], 2
    jmp .init_compiler_state

.init_compiler_state:
    mov dword [current_line], 1
    mov word [indent_count], 0
    mov word [current_indent], 0
    mov qword [token_count], 0
    mov qword [symbol_count], 0
    mov qword [pool_offset], 0
    mov byte [is_line_start], 1
    mov qword [cf_sp], 0
    mov qword [label_id_counter], 1
    mov byte [last_token_type], 0
    mov qword [cur_owner], 0
    mov qword [parse_cf_depth], 0   ; Phase 1.6: block stack empty
    mov qword [parse_brace_depth], 0 ; Phase 1.6: outside any { } body

    ; Phase 1.5b: remove any stale output so a failed compile can never
    ; leave a previous build/output.asm behind (unlink ignores errors)
    mov rax, 87
    mov rdi, out_file
    syscall

    mov rax, 2              
    mov rdi, rbx      
    mov rsi, 0              
    mov rdx, 0              
    syscall
    cmp rax, 0
    jl fatal_io
    mov r8, rax             

    mov rax, 0              
    mov rdi, r8             
    mov rsi, file_buffer    
    mov rdx, 1048576        ; Read up to 1MB of source code
    syscall
    cmp rax, 0
    jl fatal_io                  ; Phase 1.5b: read failed (was: OOB NUL write)
    cmp rax, 1048576
    jae fatal_full                  ; Phase 1.5b: no room left for the NUL
    mov byte [file_buffer + rax], 0     

    mov rax, 3              
    mov rdi, r8             
    syscall
    ret

fatal_io:                           ; source file inaccessible/unreadable
    mov rax, 1
    mov rdi, 2
    mov rsi, err_msg
    mov rdx, err_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall


fatal_full:
    mov rax, 1
    mov rdi, 2
    mov rsi, msg_fatal_full
    mov rdx, len_fatal_full
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

; Phase 1.6 parse-time block stack helpers. IN dx = indent (word).
; parse_cf_push also takes r11b = kind. All registers preserved.


parse_uint:
    push rdi
    push rdx
    xor rax, rax
.pu_loop:
    movzx edx, byte [rdi]
    cmp dl, 0
    je .pu_done
    sub dl, '0'
    cmp dl, 9
    ja .pu_done
    imul rax, rax, 10
    movzx edx, dl
    add rax, rdx
    inc rdi
    jmp .pu_loop
.pu_done:
    pop rdx
    pop rdi
    ret



print_num:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    mov rcx, 10
    mov rbx, rsp
    dec rsp
    mov byte [rsp], 10
.convert_loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rsp
    mov [rsp], dl
    cmp rax, 0
    jne .convert_loop
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, rbx
    sub rdx, rsp
    syscall
    mov rsp, rbx
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret
; Phase 1.5b: print_num to stderr (error paths keep stdout clean)
print_num_stderr:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    mov rcx, 10
    mov rbx, rsp
    dec rsp
    mov byte [rsp], 10
.convert_loop2:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rsp
    mov [rsp], dl
    cmp rax, 0
    jne .convert_loop2
    mov rax, 1
    mov rdi, 2
    mov rsi, rsp
    mov rdx, rbx
    sub rdx, rsp
    syscall
    mov rsp, rbx
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret
