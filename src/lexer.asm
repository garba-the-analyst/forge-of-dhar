; ==============================================================================
; THE FORGE OF DHAR (V0.2.3 ARCHITECTURE - Multi-Kernel Target-Triple Dispatch)
; Final Pre-Bootstrapped x86_64 Native Systems Compiler
; V0.2.3: Six-operator conditional engine (== != < > <= >=) with operator-aware
;         jump selection and variable-to-variable memory comparison.
; Author: Abdullahi Baba Garba (Garba the Analyst)
; ==============================================================================

section .data
    usage_msg db "Usage: ./build/dharc <source_file.dhar> [--target=linux|windows|wasi]", 10, 0
    usage_len equ $ - usage_msg
    err_msg db "Error: Could not open source file.", 10, 0
    err_len equ $ - err_msg
    out_file db "build/output.asm", 0
    err_out db "Error: Could not create build/output.asm", 10, 0
    err_out_len equ $ - err_out
    O_FLAGS equ 577         
    MODE equ 420            

    kw_lock db "lock", 0
    kw_flux db "flux", 0
    kw_task db "task", 0
    kw_i32 db "i32", 0
    kw_str db "str", 0
    kw_raw db "raw", 0
    kw_when db "when", 0            
    kw_span db "span", 0            
    kw_sys db "sys", 0              
    kw_fallback db "fallback", 0    
    
    ; V0.1 NEW PRIMITIVES
    kw_peek db "peek", 0
    kw_sysret db "sysret", 0
    kw_poke db "poke", 0
    kw_give db "give", 0
    kw_shift db "shift", 0
    kw_scan db "scan", 0
    kw_cycle db "cycle", 0
    kw_mold db "mold", 0
    kw_forge db "forge", 0
    kw_view db "view", 0
    kw_grab db "grab", 0
    kw_pull db "pull", 0
    kw_expose db "expose", 0
    kw_state db "state", 0
    kw_trap db "trap", 0
    kw_enforce db "enforce", 0
    kw_i8 db "i8", 0
    kw_i16 db "i16", 0
    kw_i64 db "i64", 0
    kw_u8 db "u8", 0
    kw_u16 db "u16", 0
    kw_u32 db "u32", 0
    kw_u64 db "u64", 0
    kw_f32 db "f32", 0
    kw_f64 db "f64", 0
    kw_char db "char", 0
    kw_bool db "bool", 0
    ; TARGET TRIPLE STRINGS
    str_target_linux db "--target=linux", 0
    str_target_windows db "--target=windows", 0
    str_target_wasi db "--target=wasi", 0

    msg_done db "Total tokens mapped into Memory Array: ", 0
    len_done equ $ - msg_done
    msg_parsing db 10, "--- Starting Syntactic Analysis ---", 10, 0
    len_parsing equ $ - msg_parsing
    msg_parse_ok db "Grammar Validated: All syntax rules passed.", 10, 0
    len_parse_ok equ $ - msg_parse_ok
    msg_sym_done db "Semantic Analysis: Symbol Table built successfully. Total symbols: ", 0
    len_sym_done equ $ - msg_sym_done
    msg_gen_start db 10, "--- Starting Code Generation ---", 10, 0
    len_gen_start equ $ - msg_gen_start
    msg_gen_done db "Code Generation Successful: build/output.asm created.", 10, 0
    len_gen_done equ $ - msg_gen_done

    msg_err_task db "Syntax Error: Expected Identifier after 'task' on line ", 0
    len_err_task equ $ - msg_err_task
    msg_err_var_ident db "Syntax Error: Expected Identifier after 'lock'/'flux' on line ", 0
    len_err_var_ident equ $ - msg_err_var_ident
    msg_err_var_colon db "Syntax Error: Expected ':' after variable identifier on line ", 0
    len_err_var_colon equ $ - msg_err_var_colon
    msg_err_var_type db "Syntax Error: Expected Type (i32, str, raw) after ':' on line ", 0
    len_err_var_type equ $ - msg_err_var_type
    msg_err_assign_val db "Syntax Error: Expected value after '=' on line ", 0
    len_err_assign_val equ $ - msg_err_assign_val
    msg_err_redecl db "Semantic Error: Identifier already declared on line ", 0
    len_err_redecl equ $ - msg_err_redecl
    msg_err_undecl db "Semantic Error: Assignment to undeclared variable on line ", 0
    len_err_undecl equ $ - msg_err_undecl
    msg_err_immut db "Semantic Error: Cannot reassign immutable 'lock' variable on line ", 0
    len_err_immut equ $ - msg_err_immut
    msg_err_syntax db "Syntax Error: Invalid Task Parameter Definition on line ", 0
    len_err_syntax equ $ - msg_err_syntax
    msg_err_cond db "Syntax Error: Invalid comparison operator in condition on line ", 0
    len_err_cond equ $ - msg_err_cond

    asm_data db "section .data", 10
    len_asm_data equ $ - asm_data
    asm_str_prefix db "str_"
    len_asm_str_prefix equ $ - asm_str_prefix
    asm_db_quote db " db ", 96
    len_asm_db_quote equ $ - asm_db_quote
    asm_quote_zero db 96, ", 0", 10
    len_asm_quote_zero equ $ - asm_quote_zero
    asm_bss db 10, "section .bss", 10
    len_asm_bss equ $ - asm_bss
    asm_resq db " resq 1", 10
    len_asm_resq equ $ - asm_resq
    asm_resq_base db " resq "
    len_asm_resq_base equ $ - asm_resq_base
    asm_text db 10, "section .text", 10, "    global _start", 10, "_start:", 10, "    call core", 10, "    mov rax, 60", 10, "    xor rdi, rdi", 10, "    syscall", 10, 10
    len_asm_text equ $ - asm_text
    
    asm_call db "    call "
    len_asm_call equ $ - asm_call
    asm_ret db "    ret", 10
    len_asm_ret equ $ - asm_ret

    asm_mov1 db "    mov qword ["
    len_asm_mov1 equ $ - asm_mov1
    asm_mov2 db "], "
    len_asm_mov2 equ $ - asm_mov2
    asm_mov_rax_l db "    mov rax, qword ["
    len_asm_mov_rax_l equ $ - asm_mov_rax_l
    asm_close_bracket_nl db "]", 10
    len_asm_close_bracket_nl equ $ - asm_close_bracket_nl
    asm_cmp_rax db "    cmp rax, "
    len_asm_cmp_rax equ $ - asm_cmp_rax
    asm_jne_l_end db "    jne .L_END_"
    len_asm_jne_l_end equ $ - asm_jne_l_end
    asm_jne_l_fallback db "    jne .L_FALLBACK_"
    len_asm_jne_l_fallback equ $ - asm_jne_l_fallback

    ; --- V0.2.3 Comparison Operator Conditional Jump Strings ---
    ; Semantics: jump-away-if-false. Exit jump = logical inverse of the operator.
    ;   == -> jne | != -> je | < -> jge | > -> jle | <= -> jg | >= -> jl
    asm_je_l_end db "    je .L_END_"
    len_asm_je_l_end equ $ - asm_je_l_end
    asm_je_l_fallback db "    je .L_FALLBACK_"
    len_asm_je_l_fallback equ $ - asm_je_l_fallback
    asm_jl_l_end db "    jl .L_END_"
    len_asm_jl_l_end equ $ - asm_jl_l_end
    asm_jl_l_fallback db "    jl .L_FALLBACK_"
    len_asm_jl_l_fallback equ $ - asm_jl_l_fallback
    asm_jg_l_end db "    jg .L_END_"
    len_asm_jg_l_end equ $ - asm_jg_l_end
    asm_jg_l_fallback db "    jg .L_FALLBACK_"
    len_asm_jg_l_fallback equ $ - asm_jg_l_fallback
    asm_jle_l_end db "    jle .L_END_"
    len_asm_jle_l_end equ $ - asm_jle_l_end
    asm_jle_l_fallback db "    jle .L_FALLBACK_"
    len_asm_jle_l_fallback equ $ - asm_jle_l_fallback
    asm_jge_l_end db "    jge .L_END_"
    len_asm_jge_l_end equ $ - asm_jge_l_end
    asm_jge_l_fallback db "    jge .L_FALLBACK_"
    len_asm_jge_l_fallback equ $ - asm_jge_l_fallback

    ; Memory-operand compare: RHS is a symbol (variable-to-variable comparison)
    asm_cmp_rax_mem db "    cmp rax, qword ["
    len_asm_cmp_rax_mem equ $ - asm_cmp_rax_mem
    asm_jmp_l_end db "    jmp .L_END_"
    len_asm_jmp_l_end equ $ - asm_jmp_l_end
    asm_l_fallback db ".L_FALLBACK_"
    len_asm_l_fallback equ $ - asm_l_fallback
    asm_l_end db ".L_END_"
    len_asm_l_end equ $ - asm_l_end
    asm_l_start db ".L_START_"
    len_asm_l_start equ $ - asm_l_start
    asm_jmp_l_start db "    jmp .L_START_"
    len_asm_jmp_l_start equ $ - asm_jmp_l_start
    asm_colon_nl db ":", 10
    len_asm_colon_nl equ $ - asm_colon_nl
    asm_mov_dest_rax db "    mov qword ["
    len_asm_mov_dest_rax equ $ - asm_mov_dest_rax
    asm_close_rax db "], rax", 10
    len_asm_close_rax equ $ - asm_close_rax
    asm_mov_rax_lit db "    mov rax, "
    len_asm_mov_rax_lit equ $ - asm_mov_rax_lit
    asm_add_rax_l db "    add rax, qword ["
    len_asm_add_rax_l equ $ - asm_add_rax_l
    asm_add_rax_lit db "    add rax, "
    len_asm_add_rax_lit equ $ - asm_add_rax_lit
    asm_sub_rax_l db "    sub rax, qword ["
    len_asm_sub_rax_l equ $ - asm_sub_rax_l
    asm_sub_rax_lit db "    sub rax, "
    len_asm_sub_rax_lit equ $ - asm_sub_rax_lit
    asm_mov_r8_l db "    mov r8, qword ["
    len_asm_mov_r8_l equ $ - asm_mov_r8_l
    asm_mov_r9_l db "    mov r9, qword ["
    len_asm_mov_r9_l equ $ - asm_mov_r9_l
    asm_mov_r8_lit db "    mov r8, "
    len_asm_mov_r8_lit equ $ - asm_mov_r8_lit
    asm_mov_r9_lit db "    mov r9, "
    len_asm_mov_r9_lit equ $ - asm_mov_r9_lit
    asm_mov_rcx_lit db "    mov rcx, "
    len_asm_mov_rcx_lit equ $ - asm_mov_rcx_lit
    asm_mov_rcx_l db "    mov rcx, qword ["
    len_asm_mov_rcx_l equ $ - asm_mov_rcx_l
    asm_array_store_2 db " + rax*8], rcx", 10
    len_asm_array_store_2 equ $ - asm_array_store_2
    asm_mov_rdi_l db "    mov rdi, qword ["
    len_asm_mov_rdi_l equ $ - asm_mov_rdi_l
    asm_mov_rdi_lit db "    mov rdi, "
    len_asm_mov_rdi_lit equ $ - asm_mov_rdi_lit
    asm_mov_rsi_lit db "    mov rsi, "
    len_asm_mov_rsi_lit equ $ - asm_mov_rsi_lit
    asm_mov_rsi_l db "    mov rsi, qword ["
    len_asm_mov_rsi_l equ $ - asm_mov_rsi_l
    asm_mov_rdx_l db "    mov rdx, qword ["
    len_asm_mov_rdx_l equ $ - asm_mov_rdx_l
    asm_mov_rdx_lit db "    mov rdx, "
    len_asm_mov_rdx_lit equ $ - asm_mov_rdx_lit
    asm_syscall db "    syscall", 10
    len_asm_syscall equ $ - asm_syscall

    ; --- V0.3.0 Strength-reduction folds ---
    asm_inc db "    inc qword ["
    len_asm_inc equ $ - asm_inc
    asm_dec db "    dec qword ["
    len_asm_dec equ $ - asm_dec
    kw_one db "1", 0

    ; --- V0.3.0 Multiplicative op sequences (op2 preloaded in rcx) ---
    asm_mul_line db "    imul rax, rcx", 10
    len_asm_mul_line equ $ - asm_mul_line
    asm_div_seq db "    cqo", 10, "    idiv rcx", 10
    len_asm_div_seq equ $ - asm_div_seq
    asm_mod_fix db "    mov rax, rdx", 10
    len_asm_mod_fix equ $ - asm_mod_fix

    ; --- V0.1 Peek & Sysret Assembly Generation Strings ---
    asm_peek_1 db "    mov rax, qword ["
    len_asm_peek_1 equ $ - asm_peek_1
    asm_peek_2 db "]", 10, "    mov rsi, "
    len_asm_peek_2 equ $ - asm_peek_2
    asm_peek_3 db 10, "    xor rcx, rcx", 10, "    mov cl, byte [rsi + rax]", 10, "    mov qword ["
    len_asm_peek_3 equ $ - asm_peek_3
    asm_peek_4 db "], rcx", 10
    len_asm_peek_4 equ $ - asm_peek_4

    asm_sysret_1 db "    mov qword ["
    len_asm_sysret_1 equ $ - asm_sysret_1
    asm_sysret_2 db "], rax", 10
    len_asm_sysret_2 equ $ - asm_sysret_2

    ; --- V0.3.0 Poke: byte-granular store (poke buffer, index, value) ---
    asm_poke_store db "    mov byte [rsi + rax], cl", 10
    len_asm_poke_store equ $ - asm_poke_store

    ; --- V0.3.0 Stack frames ---
    asm_rbp_prefix db "rbp-"
    len_asm_rbp_prefix equ $ - asm_rbp_prefix
    asm_prologue db "    push rbp", 10, "    mov rbp, rsp", 10, "    sub rsp, "
    len_asm_prologue equ $ - asm_prologue
    asm_epilogue db "    mov rsp, rbp", 10, "    pop rbp", 10, "    ret", 10
    len_asm_epilogue equ $ - asm_epilogue
    asm_tret_label db ".L_TRET_"
    len_asm_tret_label equ $ - asm_tret_label
    asm_jmp_tret db "    jmp .L_TRET_"
    len_asm_jmp_tret equ $ - asm_jmp_tret
    asm_lea_rsi_open db "    lea rsi, ["
    len_asm_lea_rsi_open equ $ - asm_lea_rsi_open
    asm_xor_eax db "    xor eax, eax", 10
    len_asm_xor_eax equ $ - asm_xor_eax
    asm_lea_rdi_open db "    lea rdi, ["
    len_asm_lea_rdi_open equ $ - asm_lea_rdi_open
    asm_lea_rdx_open db "    lea rdx, ["
    len_asm_lea_rdx_open equ $ - asm_lea_rdx_open
    asm_spill_q db "    mov qword [rbp-"      ; + off + "], reg"
    len_asm_spill_q equ $ - asm_spill_q
    asm_spill_close_rdi db "], rdi", 10
    len_asm_spill_close_rdi equ $ - asm_spill_close_rdi
    asm_spill_close_rsi db "], rsi", 10
    len_asm_spill_close_rsi equ $ - asm_spill_close_rsi
    asm_spill_close_rdx db "], rdx", 10
    len_asm_spill_close_rdx equ $ - asm_spill_close_rdx
    asm_spill_close_rcx db "], rcx", 10
    len_asm_spill_close_rcx equ $ - asm_spill_close_rcx
    asm_spill_close_r8 db "], r8", 10
    len_asm_spill_close_r8 equ $ - asm_spill_close_r8
    asm_spill_close_r9 db "], r9", 10
    len_asm_spill_close_r9 equ $ - asm_spill_close_r9

    asm_munmap_1 db "    ; --- Scope Cleanup (Neutered for V0) ---", 10, "    ; mov rax, 11", 10, "    ; mov rdi, "
    len_asm_munmap_1 equ $ - asm_munmap_1
    asm_munmap_2 db 10, "    ; mov rsi, "
    len_asm_munmap_2 equ $ - asm_munmap_2
    
    newline db 10

; --- V0.2.2: THE MEGABYTE EXPANSION & TARGET REGISTRY ---
section .bss
    token_array resb 1048576        ; 1MB Token Array (65,536 tokens)
    token_count resq 1              
    string_pool resb 1048576        ; 1MB String Pool
    pool_offset resq 1
    symbol_table resb 1048576       ; 1MB Symbol Table (32,768 symbols)
    symbol_count resq 1
    cf_stack resb 65536             ; 64KB Control Flow Stack
    cf_sp resq 1                    
    label_id_counter resq 1         
    file_buffer resb 1048576        ; 1MB Source File Buffer
    word_buffer resb 4096           ; 4KB Word Buffer
    word_len resq 1
    is_line_start resb 1
    indent_count resw 1             
    current_indent resw 1
    current_line resd 1
    target_os_flag resq 1           ; 0 = Linux, 1 = Windows PE, 2 = WASI
    last_token_type resb 1          ; V0.3.0 unary-minus detection

    ; --- V0.3.0 Stack-frame machinery ---
    frame_offsets resq 256          ; per-task frame sizes (bytes), 1-indexed
    task_frame_count resq 1
    scan_in_task resq 1
    scan_task_indent resd 1
    scan_task_id resq 1
    scan_frame_off resq 1
    cg_cur_task resq 1              ; codegen current task ordinal
    ecs_callee_tok resq 1           ; V0.3.0 callee token ptr during call emission
    cg_ret_label resq 1             ; label id of current task's epilogue
    in_task_flag resb 1
    parse_task_counter resq 1       ; V0.3.0 scoping: task ordinal at parse time
    cur_owner resq 1                ; V0.3.0 scoping: current declaration owner

section .text
    global _start

_start:
    mov rbx, [rsp]                  ; Load argc
    cmp rbx, 2                      
    jl .print_usage
    mov r12, [rsp + 16]             ; argv[1] is our source file

    ; --- TARGET TRIPLE PARSING ---
    mov qword [target_os_flag], 0   ; Default to Linux ELF
    cmp rbx, 3                      ; Check if target flag argument exists
    jl .init_compiler_state
    
    mov r13, [rsp + 24]             ; argv[2] is target triple flag
    
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

    mov rax, 2              
    mov rdi, r12      
    mov rsi, 0              
    mov rdx, 0              
    syscall
    cmp rax, 0
    jl .file_error
    mov r8, rax             

    mov rax, 0              
    mov rdi, r8             
    mov rsi, file_buffer    
    mov rdx, 1048576        ; Read up to 1MB of source code
    syscall
    mov byte [file_buffer + rax], 0     

    mov rax, 3              
    mov rdi, r8             
    syscall
    
    mov rsi, file_buffer    

.next_char:
    mov al, byte [rsi]
    cmp al, 0
    je .exit_lexer
    
    cmp byte [is_line_start], 1
    jne .normal_processing

    cmp al, 32                      
    je .count_space
    cmp al, 9                       
    je .count_space
    cmp al, 13                      
    je .skip_char
    cmp al, 10                      
    je .reset_line
    
    mov byte [is_line_start], 0
    mov cx, [indent_count]
    mov [current_indent], cx

.normal_processing:
    cmp al, 13
    je .skip_char
    cmp al, 10
    je .handle_newline
    cmp al, 32
    je .handle_space
    cmp al, 9
    je .handle_space
    
    cmp al, 58                      
    je .handle_colon
    cmp al, 40                      
    je .handle_lparen
    cmp al, 41                      
    je .handle_rparen
    cmp al, 61                      
    je .handle_equals
    cmp al, 43                      
    je .handle_plus
    cmp al, 45                      
    je .handle_minus
    cmp al, 91                      
    je .handle_lbracket
    cmp al, 93                      
    je .handle_rbracket
    cmp al, 44                      
    je .handle_comma
    cmp al, 34                      
    je .handle_quote
    cmp al, 59                      
    je .start_comment
    cmp al, 60                      ; '<'
    je .handle_lt
    cmp al, 62                      ; '>'
    je .handle_gt
    cmp al, 33                      ; '!'
    je .handle_bang
    cmp al, 42                      ; '*'
    je .handle_star
    cmp al, 47                      ; '/'
    je .handle_slash
    cmp al, 37                      ; '%'
    je .handle_percent
    cmp al, 123                     ; '{'
    je .handle_lbrace
    cmp al, 125                     ; '}'
    je .handle_rbrace

    mov rdi, word_buffer
    mov rcx, [word_len]
    add rdi, rcx
    mov [rdi], al
    inc qword [word_len]
    inc rsi
    jmp .next_char

.count_space:
    inc word [indent_count]
    inc rsi
    jmp .next_char
.skip_char:
    inc rsi
    jmp .next_char
.handle_space:
    call process_current_word
    inc rsi
    jmp .next_char
.handle_newline:
    call process_current_word
    inc dword [current_line]
    mov byte [is_line_start], 1
    mov word [indent_count], 0
    inc rsi
    jmp .next_char
.reset_line:
    inc dword [current_line]
    mov word [indent_count], 0
    inc rsi
    jmp .next_char

.handle_colon:
    call process_current_word
    mov r8b, 3
    mov r9b, 1
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_lparen:
    call process_current_word
    mov r8b, 3
    mov r9b, 2
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_rparen:
    call process_current_word
    mov r8b, 3
    mov r9b, 3
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_equals:
    call process_current_word
    cmp byte [rsi + 1], 61          
    je .handle_double_equals
    mov r8b, 3
    mov r9b, 4                  
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_double_equals:
    mov r8b, 3
    mov r9b, 5                  
    xor r10, r10
    call store_token
    add rsi, 2
    jmp .next_char
.handle_plus:
    call process_current_word
    mov r8b, 3
    mov r9b, 6                  
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_minus:
    call process_current_word
    ; --- V0.3.0: unary minus (negative literal) when previous token is
    ;     start-of-stream(0) or an operator/punctuator(3):  = -5 | < -3 | , -2
    mov cl, [last_token_type]
    cmp cl, 3
    je .unary_minus
    cmp cl, 0
    je .unary_minus
    mov r8b, 3
    mov r9b, 7                  
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.unary_minus:
    mov rdi, word_buffer
    mov qword [word_len], 0
    mov byte [rdi], '-'
    mov qword [word_len], 1
.um_digit_loop:
    inc rsi
    mov al, [rsi]
    cmp al, '0'
    jb .um_scan_done
    cmp al, '9'
    ja .um_scan_done
    mov rcx, [word_len]
    mov [rdi + rcx], al
    inc qword [word_len]
    jmp .um_digit_loop
.um_scan_done:
    cmp qword [word_len], 1         ; bare '-' with no digits -> binary op token
    je .um_emit_op
    call process_current_word       ; flush "-N" as numeric literal
    jmp .next_char
.um_emit_op:
    mov r8b, 3
    mov r9b, 7
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_lbracket:
    call process_current_word
    mov r8b, 3
    mov r9b, 8                  
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_rbracket:
    call process_current_word
    mov r8b, 3
    mov r9b, 9                  
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_comma:
    call process_current_word
    mov r8b, 3
    mov r9b, 10                 
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char

; --- V0.2.3: Relational operator handlers ---
; Operator subtypes: 11='<', 12='>', 13='<=', 14='>=', 15='!='
.handle_lt:
    call process_current_word
    cmp byte [rsi + 1], 61          ; '<=' ?
    je .handle_lte
    mov r8b, 3
    mov r9b, 11
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_lte:
    mov r8b, 3
    mov r9b, 13
    xor r10, r10
    call store_token
    add rsi, 2
    jmp .next_char
.handle_gt:
    call process_current_word
    cmp byte [rsi + 1], 61          ; '>=' ?
    je .handle_gte
    mov r8b, 3
    mov r9b, 12
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_gte:
    mov r8b, 3
    mov r9b, 14
    xor r10, r10
    call store_token
    add rsi, 2
    jmp .next_char
.handle_bang:
    cmp byte [rsi + 1], 61          ; '!=' ? (bare '!' is not a token)
    jne .bang_word_char
    call process_current_word
    mov r8b, 3
    mov r9b, 15
    xor r10, r10
    call store_token
    add rsi, 2
    jmp .next_char
.bang_word_char:
    mov rdi, word_buffer
    mov rcx, [word_len]
    add rdi, rcx
    mov [rdi], al
    inc qword [word_len]
    inc rsi
    jmp .next_char

; --- V0.3.0: Multiplicative operators ---
; Operator subtypes: 16='*', 17='/', 18='%'
.handle_star:
    call process_current_word
    mov r8b, 3
    mov r9b, 16
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_slash:
    call process_current_word
    mov r8b, 3
    mov r9b, 17
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_percent:
    call process_current_word
    mov r8b, 3
    mov r9b, 18
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_lbrace:
    call process_current_word
    mov r8b, 3
    mov r9b, 19
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char
.handle_rbrace:
    call process_current_word
    mov r8b, 3
    mov r9b, 20
    xor r10, r10
    call store_token
    inc rsi
    jmp .next_char

.start_comment:
    call process_current_word
.comment_loop:
    inc rsi
    mov al, [rsi]
    cmp al, 0
    je .exit_lexer
    cmp al, 13
    je .comment_loop
    cmp al, 10
    je .handle_newline
    jmp .comment_loop

.handle_quote:
    call process_current_word
    mov rdi, word_buffer
    mov qword [word_len], 0
.quote_loop:
    inc rsi
    mov al, [rsi]
    cmp al, 0
    je .file_error
    cmp al, 34                  
    je .quote_done
    mov rcx, [word_len]
    mov [rdi + rcx], al
    inc qword [word_len]
    jmp .quote_loop
.quote_done:
    mov rcx, [word_len]
    mov byte [rdi + rcx], 0
    call save_string
    mov r8b, 6                  
    mov r9b, 0
    mov r10, rax
    call store_token
    mov qword [word_len], 0
    inc rsi
    jmp .next_char

.print_usage:
    mov rax, 1
    mov rdi, 1
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall
.file_error:
    mov rax, 1
    mov rdi, 2
    mov rsi, err_msg
    mov rdx, err_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall
.exit_lexer:
    call process_current_word
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_done
    mov rdx, len_done
    syscall
    mov rax, [token_count]
    call print_num
    
    call run_parser
    call run_codegen
    
    mov rax, 60                     
    xor rdi, rdi
    syscall

run_parser:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_parsing
    mov rdx, len_parsing
    syscall
    xor rcx, rcx                    

.parse_loop:
    cmp rcx, [token_count]          
    jge .parse_success
    mov rax, rcx
    shl rax, 4                      
    lea rbx, [token_array + rax]    
    mov r8b, [rbx]                  
    mov r9b, [rbx + 1]              
    cmp r8b, 1                      
    je .check_keyword
    cmp r8b, 2                      
    je .check_identifier
    jmp .next_token

.check_keyword:
    cmp r9b, 1                      
    je .check_var_decl
    cmp r9b, 2                      
    je .check_var_decl
    cmp r9b, 3                      
    je .check_task_decl
    cmp r9b, 4                      
    je .check_cf_stmt               
    cmp r9b, 5                      
    je .check_cf_stmt
    cmp r9b, 6                      
    je .check_sys_stmt
    cmp r9b, 7                      
    je .check_fallback_stmt
    cmp r9b, 8
    je .check_peek_stmt
    cmp r9b, 9
    je .check_sysret_stmt
    cmp r9b, 10                     ; poke
    je .check_poke_stmt
    cmp r9b, 11                     ; give
    je .check_give_stmt
    cmp r9b, 12                     ; shift
    je .check_shift_stmt
    cmp r9b, 13                     ; scan
    je .check_scan_stmt
    cmp r9b, 14                     ; cycle
    je .check_cycle_stmt
    cmp r9b, 15                     ; mold
    je .check_mold_stmt
    cmp r9b, 16                     ; forge
    je .check_forge_stmt
    cmp r9b, 17                     ; view
    je .check_view_stmt
    cmp r9b, 18                     ; grab
    je .check_grab_stmt
    cmp r9b, 19                     ; pull
    je .check_pull_stmt
    cmp r9b, 20                     ; expose
    je .check_expose_stmt
    cmp r9b, 21                     ; state
    je .check_state_stmt
    cmp r9b, 22                     ; trap
    je .check_trap_stmt
    cmp r9b, 23                     ; enforce
    je .check_enforce_stmt
    jmp .next_token

.check_peek_stmt:
    add rcx, 5
    jmp .next_token
.check_poke_stmt:
    add rcx, 5                      ; poke buf, idx, val -> 6 tokens total
    jmp .next_token

.check_give_stmt:
    ; V0.3.0: 'give' optionally carries one same-line operand.
    ; Accounting: leave rcx on LAST consumed token; .next_token supplies the
    ; final increment (bare = net 1, with operand = net 2).
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .next_token                 ; bare give
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]              ; line of 'give'
    cmp edx, [r12 + 4]
    jne .next_token                 ; operand on next line -> bare
    cmp byte [r12], 2               ; identifier
    je .check_give_operand_ok
    cmp byte [r12], 5               ; number
    je .check_give_operand_ok
    jmp .next_token
.check_give_operand_ok:
    ; reject calls as return values for now (ident followed by '(')
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .give_consume_operand
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .give_consume_operand
    cmp byte [r12 + 1], 2           ; '(' -> unsupported call-return
    je .err_give_call
.give_consume_operand:
    add rcx, 1                      ; point at operand
    jmp .next_token

.err_give_call:
    mov rsi, msg_err_syntax
    mov rdx, len_err_syntax
    jmp .print_syntax_err
.check_shift_stmt:
    add rcx, 3
    jmp .next_token
.check_scan_stmt:
    add rcx, 3
    jmp .next_token
.check_cycle_stmt:
    jmp .next_token
.check_mold_stmt:
    add rcx, 2
    jmp .next_token
.check_forge_stmt:
    add rcx, 2
    jmp .next_token
.check_view_stmt:
    add rcx, 1
    jmp .next_token
.check_grab_stmt:
    add rcx, 1
    jmp .next_token
.check_pull_stmt:
    add rcx, 1
    jmp .next_token
.check_expose_stmt:
    add rcx, 1
    jmp .next_token
.check_state_stmt:
    add rcx, 2
    jmp .next_token
.check_trap_stmt:
    add rcx, 1
    jmp .next_token
.check_enforce_stmt:
    add rcx, 1
    jmp .next_token
.check_sysret_stmt:
    add rcx, 1
    jmp .next_token

.check_fallback_stmt:
    add rcx, 1                      
    jmp .next_token
.check_cf_stmt:
    ; Condition grammar: [when|span] [identifier] [cmp-op] [value]
    ; Valid operators: '=='(5), '<'(11), '>'(12), '<='(13), '>='(14), '!='(15)
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_bad_condition
    mov r11b, [r12 + 1]
    cmp r11b, 5                     ; '=='
    je .cond_op_valid
    cmp r11b, 11                    ; relational block: 11..15
    jb .err_bad_condition
    cmp r11b, 15
    ja .err_bad_condition

.cond_op_valid:
    mov rax, rcx
    add rax, 3                      ; RHS value must exist
    cmp rax, [token_count]
    jge .err_bad_condition
    add rcx, 4
    jmp .next_token
.check_sys_stmt:
    add rcx, 7
    jmp .next_token

.check_task_decl:
    mov rax, rcx
    inc rax                         
    cmp rax, [token_count]
    jge .err_expected_identifier
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2                      
    jne .err_expected_identifier

    mov r13, [r12 + 8]              
    mov r14d, [rbx + 4]             
    mov r15w, [rbx + 2]             
    call check_symbol_collision
    cmp rax, 1
    je .err_redeclared

    mov r8b, 3                      
    mov r9b, 0                      
    call add_symbol
    inc qword [parse_task_counter]
    mov rax, [parse_task_counter]
    mov [cur_owner], rax            ; V0.3.0: body decls owned by this task
    add rcx, 1                      

    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .task_decl_done
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .task_decl_done
    cmp byte [r12 + 1], 2           
    jne .task_decl_done
    add rcx, 1                      

.parse_params_loop:
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_syntax

    shl rax, 4
    lea r12, [token_array + rax]
    
    cmp byte [r12], 3
    je .check_empty_param_end
    cmp byte [r12], 2
    jne .err_syntax

    mov r13, [r12 + 8]              
    mov rax, rcx
    add rax, 2
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_syntax
    cmp byte [r12 + 1], 1           
    jne .err_syntax

    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 4               
    jne .err_syntax
    mov r11b, [r12 + 1]

    mov r8b, 5                      
    mov r9b, r11b
    xor r10, r10
    call add_symbol
    add rcx, 3

    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_syntax

    cmp byte [r12 + 1], 10          
    je .param_comma
    cmp byte [r12 + 1], 3           
    je .param_end
    jmp .err_syntax

.param_comma:
    add rcx, 1
    jmp .parse_params_loop

.check_empty_param_end:
    cmp byte [r12 + 1], 3           
    je .param_end
    jmp .err_syntax

.param_end:
    add rcx, 1
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .task_decl_done
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .task_decl_done
    cmp byte [r12 + 1], 1           
    jne .task_decl_done
    add rcx, 1

.task_decl_done:
    jmp .next_token

.check_var_decl:
    xor r10, r10                    
    mov r11b, r9b                   
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_var_ident
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2                       
    jne .err_var_ident
    mov r13, [r12 + 8]              

    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_var_colon
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3                       
    jne .err_var_colon
    cmp byte [r12 + 1], 1                       
    jne .err_var_colon

    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_var_type
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 4                       
    jne .err_var_type
    
    mov r9b, [r12 + 1]              
    mov r14d, [rbx + 4]             
    mov r15w, [rbx + 2]             
    
    mov rdi, 3                      

    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .check_inline_assign            

    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3               
    jne .check_inline_assign            
    cmp byte [r12 + 1], 8           
    jne .check_inline_assign            

    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_var_type               
    shl rax, 4
    lea r8, [token_array + rax]     
    cmp byte [r8], 5                
    jne .err_var_type

    mov r10, [r8 + 8]               

    mov rax, rcx
    add rax, 6
    cmp rax, [token_count]
    jge .err_var_type
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3               
    jne .err_var_type
    cmp byte [r12 + 1], 9           
    jne .err_var_type

    add r11b, 10                    
    add rdi, 3                      

.check_inline_assign:
    mov rax, rcx
    add rax, rdi
    inc rax
    cmp rax, [token_count]
    jge .finish_var_decl
    
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .finish_var_decl
    cmp byte [r12 + 1], 4           
    jne .finish_var_decl
    
    mov rax, rcx
    add rax, rdi
    add rax, 2
    cmp rax, [token_count]
    jge .err_assign_val
    shl rax, 4
    lea r12, [token_array + rax]
    
    cmp byte [r12], 5
    je .valid_inline_rhs
    cmp byte [r12], 6
    je .valid_inline_rhs
    cmp byte [r12], 2
    je .valid_inline_rhs
    jmp .err_assign_val
    
.valid_inline_rhs:
    add rdi, 2                      

.finish_var_decl:
    call check_symbol_collision_scoped
    cmp rax, 1
    je .err_redeclared

    mov r8b, r11b                   
    call add_symbol
    add rcx, rdi                    
    jmp .next_token

.check_identifier:
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .next_token                 

    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3               
    jne .next_token
    
    cmp byte [r12 + 1], 4           
    je .valid_assign
    cmp byte [r12 + 1], 8
    je .valid_assign
    
    cmp byte [r12 + 1], 2           
    je .valid_task_call
    jmp .next_token                 

.valid_task_call:
    mov r13, [rbx + 8]              
    mov r14d, [rbx + 4]             
    call find_symbol
    cmp rax, 0
    je .err_undeclared

    ; V0.3.0: validate full argument list (max 6, System V registers)
    mov r8, rcx
    cmp r8, [token_count]
    jge .err_syntax
    xor r9, r9                      ; arg count
    xor r10, r10                    ; paren depth
.vtc_walk:
    inc r8
    cmp r8, [token_count]
    jge .err_syntax
    mov rax, r8
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    je .vtc_op
    cmp byte [r12], 2               ; identifier arg
    je .vtc_arg
    cmp byte [r12], 5               ; numeric literal
    je .vtc_arg
    cmp byte [r12], 6               ; string literal
    je .vtc_arg
    jmp .err_syntax
.vtc_arg:
    inc r9
    cmp r9, 6
    jg .err_syntax
    jmp .vtc_walk
.vtc_op:
    cmp byte [r12 + 1], 2
    jne .vtc_nopen
    inc r10
    jmp .vtc_walk
.vtc_nopen:
    cmp byte [r12 + 1], 3
    jne .vtc_nclose
    cmp r10, 1
    je .vtc_close                   ; depth 1 -> closing paren of call
    dec r10
    jmp .vtc_walk
.vtc_nclose:
    cmp byte [r12 + 1], 10          ; ','
    jne .err_syntax
    jmp .vtc_walk
.vtc_close:
    mov rcx, r8                     ; park on ')': .next_token completes consumption
    jmp .next_token

.valid_assign:
    mov r13, [rbx + 8]              
    mov r14d, [rbx + 4]             
    call find_symbol
    cmp rax, 0
    je .err_undeclared

    mov r11b, [rdx + 8]             
    cmp r11b, 1                     
    je .err_immutable

    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .normal_assign_skip
    shl rax, 4
    lea r12, [token_array + rax]
    
    cmp byte [r12], 1
    je .check_sys_assign_parser

.normal_assign_skip:
    add rcx, 2                      
    jmp .next_token

.check_sys_assign_parser:
    cmp byte [r12 + 1], 6           
    jne .normal_assign_skip
    add rcx, 9                      
    jmp .next_token

.next_token:
    inc rcx                         
    jmp .parse_loop

.err_syntax:
    mov rsi, msg_err_syntax
    mov rdx, len_err_syntax
    jmp .print_syntax_err
.err_bad_condition:
    mov rsi, msg_err_cond
    mov rdx, len_err_cond
    jmp .print_syntax_err
.err_expected_identifier:
    mov rsi, msg_err_task
    mov rdx, len_err_task
    jmp .print_syntax_err
.err_var_ident:
    mov rsi, msg_err_var_ident
    mov rdx, len_err_var_ident
    jmp .print_syntax_err
.err_var_colon:
    mov rsi, msg_err_var_colon
    mov rdx, len_err_var_colon
    jmp .print_syntax_err
.err_var_type:
    mov rsi, msg_err_var_type
    mov rdx, len_err_var_type
    jmp .print_syntax_err
.err_assign_val:
    mov rsi, msg_err_assign_val
    mov rdx, len_err_assign_val
.print_syntax_err:
    mov rax, 1
    mov rdi, 1
    syscall
    xor rax, rax
    mov eax, dword [rbx + 4]        
    call print_num
    mov rax, 60
    mov rdi, 1
    syscall
.err_redeclared:
    mov rsi, msg_err_redecl
    mov rdx, len_err_redecl
    jmp .print_sem_err
.err_undeclared:
    mov rsi, msg_err_undecl
    mov rdx, len_err_undecl
    jmp .print_sem_err
.err_immutable:
    mov rsi, msg_err_immut
    mov rdx, len_err_immut
.print_sem_err:
    mov rax, 1
    mov rdi, 1
    syscall
    xor rax, rax
    mov eax, r14d        
    call print_num
    mov rax, 60
    mov rdi, 1
    syscall

.parse_success:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_parse_ok
    mov rdx, len_parse_ok
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_sym_done
    mov rdx, len_sym_done
    syscall
    mov rax, [symbol_count]
    call print_num
    ret


; ------------------------------------------------------------------------------
; V0.3.0 emit_call_sequence: rcx = callee identifier token index.
; Loads up to 6 args into rdi,rsi,rdx,rcx,r8,r9 then emits `call <name>`.
; Returns r11 = index of the closing ')' token. Preserves rbx.
; ------------------------------------------------------------------------------
emit_call_sequence:
    push r10
    push r9
    push r13
    mov rax, rcx                    ; V0.3.0: resolve callee token by INDEX
    shl rax, 4                      ; (rbx is the DEST token in assign context!)
    lea rax, [token_array + rax]
    mov [ecs_callee_tok], rax
    mov r10, rcx
    inc r10
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
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
run_codegen:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_gen_start
    mov rdx, len_gen_start
    syscall

    call precompute_frames         ; V0.3.0: mark locals + rbp offsets before emission

    mov rax, 2
    mov rdi, out_file
    mov rsi, O_FLAGS        
    mov rdx, MODE           
    syscall
    cmp rax, 0
    jl .out_err
    mov r15, rax            

    mov rsi, asm_data
    mov rdx, len_asm_data
    call write_to_file

    xor rcx, rcx
.data_loop:
    cmp rcx, [token_count]
    jge .data_done
    mov rax, rcx
    shl rax, 4
    lea rbx, [token_array + rax]
    
    cmp byte [rbx], 6               
    jne .data_skip

    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    call write_rax_to_file
    
    mov rsi, asm_db_quote
    mov rdx, len_asm_db_quote
    call write_to_file

    mov rdi, [rbx + 8]              
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file

    mov rsi, asm_quote_zero
    mov rdx, len_asm_quote_zero
    call write_to_file

.data_skip:
    inc rcx
    jmp .data_loop
.data_done:

    mov rsi, asm_bss
    mov rdx, len_asm_bss
    call write_to_file

    xor rcx, rcx
.bss_loop:
    cmp rcx, [symbol_count]
    jge .bss_done
    mov rax, rcx
    shl rax, 5
    lea rbx, [symbol_table + rax]
    
    cmp byte [rbx + 8], 3
    je .bss_skip
    cmp byte [rbx + 8], 5           
    je .bss_skip
    test byte [rbx + 9], 0x80       ; V0.3.0: stack locals are not globals
    jnz .bss_skip

    mov rdi, [rbx]          
    call get_strlen
    mov rdx, rax            
    mov rsi, rdi            
    call write_to_file

    cmp qword [rbx + 24], 0
    jne .bss_emit_array

    mov rsi, asm_resq
    mov rdx, len_asm_resq
    call write_to_file
    jmp .bss_skip

.bss_emit_array:
    mov rsi, asm_resq_base
    mov rdx, len_asm_resq_base
    call write_to_file
    mov rdi, [rbx + 24]             
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.bss_skip:
    inc rcx
    jmp .bss_loop
.bss_done:

    mov rsi, asm_text
    mov rdx, len_asm_text
    call write_to_file

    xor rcx, rcx
.text_loop:
    cmp rcx, [token_count]
    jge .text_done
    mov rax, rcx
    shl rax, 4                      
    lea rbx, [token_array + rax]

.check_cf_close:
    cmp qword [cf_sp], 0
    je .cf_close_done
    
    mov r14, [cf_sp]
    dec r14
    shl r14, 5                      
    lea r12, [cf_stack + r14]
    
    mov dx, [rbx + 2]       
    cmp dx, [r12 + 8]       
    jg .cf_close_done       
    
    mov rdi, [r12]                  
    mov r13, [r12 + 16]             

    cmp byte [rbx], 1
    jne .normal_close
    cmp byte [rbx + 1], 7           
    jne .normal_close
    cmp r13, 1                      
    jne .normal_close
    call emit_jmp_end               
    call emit_fallback_label        
    mov qword [r12 + 16], 3         
    add rcx, 1                      
    jmp .text_skip                  

.normal_close:
    cmp r13, 4                      
    je .task_close
    cmp r13, 2                      
    jne .not_span_close
    call emit_jmp_start
    jmp .not_when_close
.task_close:
    mov byte [in_task_flag], 0
    call emit_task_epilogue                   
    jmp .do_cleanup
.not_span_close:
    cmp r13, 1
    jne .not_when_close
    call emit_fallback_label        
.not_when_close:
    call emit_end_label             
.do_cleanup:
    mov r9w, [r12 + 8]
    call emit_scope_cleanup
    dec qword [cf_sp]
    jmp .check_cf_close
.cf_close_done:

    cmp byte [rbx], 1
    je .handle_keyword
    cmp byte [rbx], 2
    je .check_assign
    jmp .text_skip

.handle_keyword:
    cmp byte [rbx + 1], 1
    je .handle_var_decl_cg          
    cmp byte [rbx + 1], 2
    je .handle_var_decl_cg
    cmp byte [rbx + 1], 3
    je .handle_task
    cmp byte [rbx + 1], 4
    je .handle_control_flow
    cmp byte [rbx + 1], 5
    je .handle_control_flow
    cmp byte [rbx + 1], 6
    je .handle_syscall
    cmp byte [rbx + 1], 8
    je .handle_peek
    cmp byte [rbx + 1], 9
    je .handle_sysret
    cmp byte [rbx + 1], 10          ; poke
    je .handle_poke
    cmp byte [rbx + 1], 11          ; give
    je .handle_give
    cmp byte [rbx + 1], 12          ; shift
    je .handle_shift
    cmp byte [rbx + 1], 13          ; scan
    je .handle_scan
    cmp byte [rbx + 1], 14          ; cycle
    je .handle_cycle
    cmp byte [rbx + 1], 15          ; mold
    je .handle_mold
    cmp byte [rbx + 1], 16          ; forge
    je .handle_forge
    cmp byte [rbx + 1], 17          ; view
    je .handle_view
    cmp byte [rbx + 1], 18          ; grab
    je .handle_grab
    cmp byte [rbx + 1], 19          ; pull
    je .handle_pull
    cmp byte [rbx + 1], 20          ; expose
    je .handle_expose
    cmp byte [rbx + 1], 21          ; state
    je .handle_state
    cmp byte [rbx + 1], 22          ; trap
    je .handle_trap
    cmp byte [rbx + 1], 23          ; enforce
    je .handle_enforce
    jmp .text_skip

.handle_poke:
    ; poke buf, idx, val : buf@+1, idx@+3, val@+5
    ; load index into rax
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 5
    je .pk_idx_lit
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .pk_buf
.pk_idx_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r12 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.pk_buf:
    ; base address of buffer into rsi (V0.3.0: lea for locals)
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    mov r13, rdi
    call find_symbol
    cmp rax, 1
    jne .pk_buf_global
    test byte [rdx + 9], 0x80
    jz .pk_buf_global
    push rdx
    mov rsi, asm_lea_rsi_open
    mov rdx, len_asm_lea_rsi_open
    call write_to_file
    pop rdx
    push rdx
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]"
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .pk_val
.pk_buf_global:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.pk_val:
    ; value into rcx
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 5
    je .pk_val_lit
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .pk_emit
.pk_val_lit:
    mov rsi, asm_mov_rcx_lit
    mov rdx, len_asm_mov_rcx_lit
    call write_to_file
    mov rdi, [r12 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.pk_emit:
    mov rsi, asm_poke_store
    mov rdx, len_asm_poke_store
    call write_to_file
    add rcx, 5          
    jmp .text_skip

.handle_peek:
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r12, [token_array + rax] 

    ; V0.3.0: index operand may be literal or variable
    cmp byte [r12], 5
    je .peek_idx_lit
    mov rsi, asm_peek_1
    mov rdx, len_asm_peek_1
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .peek_buf_emit
.peek_idx_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r12 + 8] 
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.peek_buf_emit:
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax] 

    ; V0.3.0: local buffers are frame-resident -> lea rsi, [rbp-N]
    mov rdi, [r12 + 8]
    mov r13, rdi
    call find_symbol
    cmp rax, 1
    jne .peek_buf_global
    test byte [rdx + 9], 0x80
    jz .peek_buf_global
    push rdx
    mov rsi, asm_lea_rsi_open
    mov rdx, len_asm_lea_rsi_open
    call write_to_file
    pop rdx
    push rdx
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]"
    mov rdx, len_asm_close_bracket_nl
    jmp .peek_buf_written
.peek_buf_global:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r12 + 8]
    mov r13, rdi
    call emit_named_operand
    mov rsi, newline
    mov rdx, 1
.peek_buf_written:
    call write_to_file

    mov rsi, asm_peek_3
    mov rdx, len_asm_peek_3
    call write_to_file

    mov rax, rcx
    add rax, 1
    shl rax, 4
    lea r12, [token_array + rax] 
    
    mov rdi, [r12 + 8] 
    call emit_named_operand

    mov rsi, asm_peek_4
    mov rdx, len_asm_peek_4
    call write_to_file

    add rcx, 5          
    jmp .text_skip

.handle_sysret:
    mov rax, rcx
    add rax, 1
    shl rax, 4
    lea r12, [token_array + rax]
    
    mov rsi, asm_sysret_1
    mov rdx, len_asm_sysret_1
    call write_to_file
    
    mov rdi, [r12 + 8]
    
    call emit_named_operand
    
    mov rsi, asm_sysret_2
    mov rdx, len_asm_sysret_2
    call write_to_file
    
    add rcx, 1          
    jmp .text_skip

.handle_var_decl_cg:
    mov r14, 3                      
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .var_cg_no_assign
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .var_cg_check_eq
    cmp byte [r12+1], 8             
    jne .var_cg_check_eq
    add r14, 3                      
.var_cg_check_eq:
    mov rax, rcx
    add rax, r14
    inc rax
    cmp rax, [token_count]
    jge .var_cg_no_assign
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .var_cg_no_assign
    cmp byte [r12+1], 4             
    jne .var_cg_no_assign
    
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r8, [token_array + rax]     
    mov rax, rcx
    add rax, r14
    add rax, 2
    shl rax, 4
    lea r13, [token_array + rax]    
    
    mov rsi, asm_mov1
    mov rdx, len_asm_mov1
    call write_to_file
    mov rdi, [r8 + 8]
    call emit_named_operand
    mov rsi, asm_mov2
    mov rdx, len_asm_mov2
    call write_to_file
    
    cmp byte [r13], 6               
    je .cg_inline_str
    mov rdi, [r13 + 8]      
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    jmp .cg_inline_end
.cg_inline_str:
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    add rax, r14
    add rax, 2
    call write_rax_to_file
.cg_inline_end:
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rax, r14
    add rax, 2
    add rcx, rax
    jmp .text_skip
.var_cg_no_assign:
    add rcx, r14
    jmp .text_skip

.handle_task:
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]
    
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rdi, [r12 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file

    ; --- V0.3.0 prologue ---
    inc qword [cg_cur_task]
    mov rax, [cg_cur_task]
    mov [cg_ret_label], rax
    mov byte [in_task_flag], 1
    push rcx                        ; SAVE token index (rcx is the parse cursor!)
    mov rsi, asm_prologue
    mov rdx, len_asm_prologue
    call write_to_file
    mov rax, [frame_offsets + rax*8 - 8]  ; frame size for THIS ordinal
    call write_rax_to_file          ; preserves rcx
    mov rsi, newline
    mov rdx, 1
    call write_to_file

    ; --- V0.3.0 spill params into frame slots ---
    mov r10, rcx                    ; walker
    xor r9, r9                      ; ordinal
    xor r8, r8                      ; paren depth
.spill_walk:
    inc r10
    cmp r10, [token_count]
    jge .spill_done
    mov rax, r10
    shl rax, 4
    lea r13, [token_array + rax]
    cmp byte [r13], 3
    je .spill_op
    cmp byte [r13], 2               ; parameter identifier
    jne .spill_walk
    cmp r8, 1                       ; params live at depth 1 only
    jne .spill_walk
    cmp r9, 6                       ; > 6 params unsupported in regs (parser guards)
    jge .spill_walk_adv
    mov r14, r13                    ; save token ptr
    mov rdi, [r13 + 8]
    mov r13, rdi
    call find_symbol                ; -> rdx = symbol
    cmp rax, 1
    jne .spill_walk_adv
    mov eax, [rdx + 16]           ; slot distance
    push r9
    mov rsi, asm_spill_q            ; "    mov qword [rbp-"
    mov rdx, len_asm_spill_q
    call write_to_file
    pop r9                          ; rax still holds slot offset (write preserves)
    call write_rax_to_file
    cmp r9, 0
    je .sp_close_rdi
    cmp r9, 1
    je .sp_close_rsi
    cmp r9, 2
    je .sp_close_rdx
    cmp r9, 3
    je .sp_close_rcx
    cmp r9, 4
    je .sp_close_r8
    jmp .sp_close_r9
.sp_close_rdi:
    mov rsi, asm_spill_close_rdi
    mov rdx, len_asm_spill_close_rdi
    jmp .sp_write_close
.sp_close_rsi:
    mov rsi, asm_spill_close_rsi
    mov rdx, len_asm_spill_close_rsi
    jmp .sp_write_close
.sp_close_rdx:
    mov rsi, asm_spill_close_rdx
    mov rdx, len_asm_spill_close_rdx
    jmp .sp_write_close
.sp_close_rcx:
    mov rsi, asm_spill_close_rcx
    mov rdx, len_asm_spill_close_rcx
    jmp .sp_write_close
.sp_close_r8:
    mov rsi, asm_spill_close_r8
    mov rdx, len_asm_spill_close_r8
    jmp .sp_write_close
.sp_close_r9:
    mov rsi, asm_spill_close_r9
    mov rdx, len_asm_spill_close_r9
.sp_write_close:
    call write_to_file
    inc r9
    jmp .spill_walk
.spill_walk_adv:
    inc r9
    jmp .spill_walk
.spill_op:
    cmp byte [r13 + 1], 2           ; '('
    jne .sp_op_nopen
    inc r8
    jmp .spill_walk
.sp_op_nopen:
    cmp byte [r13 + 1], 3           ; ')'
    jne .sp_op_nclose
    dec r8
    jmp .spill_walk
.sp_op_nclose:
    cmp byte [r13 + 1], 1           ; ':' at depth 0 ends signature
    jne .spill_walk
    cmp r8, 0
    jne .spill_walk
    jmp .spill_done
.spill_done:
    pop rcx

    mov r14, [cf_sp]
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov qword [r11], 0
    mov dx, [rbx + 2]               
    mov [r11 + 8], dx
    mov qword [r11 + 16], 4         
    inc qword [cf_sp]
    xor r8, r8                      ; paren depth for signature skip
    
.skip_task_tokens:
    ; V0.3.0: depth-aware - param type colons must not end the signature
    inc rcx
    mov rax, rcx
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3               
    jne .skip_task_tokens
    cmp byte [r12 + 1], 2           ; '('
    je .stt_open
    cmp byte [r12 + 1], 3           ; ')'
    je .stt_close
    cmp byte [r12 + 1], 1           ; ':' ends signature only at depth 0
    jne .skip_task_tokens
    cmp r8, 0
    jne .skip_task_tokens
    jmp .text_skip
.stt_open:
    inc r8
    jmp .skip_task_tokens
.stt_close:
    dec r8
    jmp .skip_task_tokens

.handle_control_flow:
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]    
    
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r13, [token_array + rax]    
    
    mov rdi, [label_id_counter]
    inc qword [label_id_counter]
    
    mov r14, [cf_sp]
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov [r11], rdi                  
    mov dx, [rbx + 2]               
    mov [r11 + 8], dx               
    
    cmp byte [rbx + 1], 5
    je .setup_while
.setup_if:
    mov qword [r11 + 16], 1
    jmp .finish_cf_setup
.setup_while:
    mov qword [r11 + 16], 2
    push rdi
    call emit_start_label
    pop rdi
.finish_cf_setup:
    inc qword [cf_sp]
    
    push rdi

    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file

    ; --- Compare: identifier RHS loads memory operand; otherwise literal text ---
    cmp byte [r13], 2
    je .emit_cmp_rhs_mem
    mov rsi, asm_cmp_rax
    mov rdx, len_asm_cmp_rax
    call write_to_file
    mov rdi, [r13 + 8]              
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .select_cond_jump
.emit_cmp_rhs_mem:
    mov rsi, asm_cmp_rax_mem
    mov rdx, len_asm_cmp_rax_mem
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file

    ; --- Select exit jump: logical inverse of the condition operator ---
.select_cond_jump:
    mov rax, rcx
    add rax, 2
    shl rax, 4
    lea r12, [token_array + rax]
    movzx r13d, byte [r12 + 1]      ; operator subtype (dispatch BEFORE any reg reuse)

    cmp r13b, 15                    ; '!=' -> je
    je .sel_op_ne
    cmp r13b, 11                    ; '<' -> jge
    je .sel_op_lt
    cmp r13b, 12                    ; '>' -> jle
    je .sel_op_gt
    cmp r13b, 13                    ; '<=' -> jg
    je .sel_op_le
    cmp r13b, 14                    ; '>=' -> jl
    je .sel_op_ge

    ; Default: '==' -> jne
    mov r8, asm_jne_l_end
    mov r9, len_asm_jne_l_end
    mov r10, asm_jne_l_fallback
    mov r11, len_asm_jne_l_fallback
    jmp .pick_label_variant

.sel_op_ne:
    mov r8, asm_je_l_end
    mov r9, len_asm_je_l_end
    mov r10, asm_je_l_fallback
    mov r11, len_asm_je_l_fallback
    jmp .pick_label_variant
.sel_op_lt:
    mov r8, asm_jge_l_end
    mov r9, len_asm_jge_l_end
    mov r10, asm_jge_l_fallback
    mov r11, len_asm_jge_l_fallback
    jmp .pick_label_variant
.sel_op_gt:
    mov r8, asm_jle_l_end
    mov r9, len_asm_jle_l_end
    mov r10, asm_jle_l_fallback
    mov r11, len_asm_jle_l_fallback
    jmp .pick_label_variant
.sel_op_le:
    mov r8, asm_jg_l_end
    mov r9, len_asm_jg_l_end
    mov r10, asm_jg_l_fallback
    mov r11, len_asm_jg_l_fallback
    jmp .pick_label_variant
.sel_op_ge:
    mov r8, asm_jl_l_end
    mov r9, len_asm_jl_l_end
    mov r10, asm_jl_l_fallback
    mov r11, len_asm_jl_l_fallback

.pick_label_variant:
    cmp byte [rbx + 1], 4           ; 'when' exits to fallback label
    je .use_fallback_jump
    mov rsi, r8
    mov rdx, r9
    jmp .write_cond_jump
.use_fallback_jump:
    mov rsi, r10
    mov rdx, r11
.write_cond_jump:
    call write_to_file
    pop rax
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    add rcx, 4                      
    jmp .text_skip

.handle_syscall:
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r13, [token_array + rax]
    
    cmp byte [r13], 5
    je .sys_rax_lit
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_rdi
.sys_rax_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.sys_rdi:
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r13, [token_array + rax]
    
    cmp byte [r13], 5
    je .sys_rdi_lit

    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rdi_normal
    cmp byte [rdx + 9], 3      
    jne .sys_rdi_normal
    test byte [rdx + 9], 0x80          
    jz .sys_rdi_lit
    push rdx
    mov rsi, asm_lea_rdi_open
    mov rdx, len_asm_lea_rdi_open
    call write_to_file
    pop rdx
    push rdx
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    mov rsi, asm_spill_close_rdi
    mov rdx, len_asm_spill_close_rdi
    call write_to_file
    jmp .sys_rsi
.sys_rdi_normal:
    mov rsi, asm_mov_rdi_l
    mov rdx, len_asm_mov_rdi_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_rsi
.sys_rdi_lit:
    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.sys_rsi:
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r13, [token_array + rax]
    
    cmp byte [r13], 6               
    je .sys_rsi_str
    cmp byte [r13], 5
    je .sys_rsi_lit

    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rsi_normal
    cmp byte [rdx + 9], 3      
    jne .sys_rsi_normal
    test byte [rdx + 9], 0x80          
    jz .sys_rsi_lit
    push rdx
    mov rsi, asm_lea_rsi_open
    mov rdx, len_asm_lea_rsi_open
    call write_to_file
    pop rdx
    push rdx
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    mov rsi, asm_spill_close_rsi
    mov rdx, len_asm_spill_close_rsi
    call write_to_file
    jmp .sys_rdx
.sys_rsi_normal:
    mov rsi, asm_mov_rsi_l
    mov rdx, len_asm_mov_rsi_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_rdx

.sys_rsi_lit:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_rdx

.sys_rsi_str:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    add rax, 5
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.sys_rdx:
    mov rax, rcx
    add rax, 7
    shl rax, 4
    lea r13, [token_array + rax]
    
    cmp byte [r13], 5
    je .sys_rdx_lit

    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rdx_normal
    cmp byte [rdx + 9], 3      
    jne .sys_rdx_normal
    test byte [rdx + 9], 0x80          
    jz .sys_rdx_lit
    push rdx
    mov rsi, asm_lea_rdx_open
    mov rdx, len_asm_lea_rdx_open
    call write_to_file
    pop rdx
    push rdx
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    mov rsi, asm_spill_close_rdx
    mov rdx, len_asm_spill_close_rdx
    call write_to_file
    jmp .sys_emit
.sys_rdx_normal:
    mov rsi, asm_mov_rdx_l
    mov rdx, len_asm_mov_rdx_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_emit
.sys_rdx_lit:
    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.sys_emit:
    mov rsi, asm_syscall
    mov rdx, len_asm_syscall
    call write_to_file
    add rcx, 7
    jmp .text_skip

.handle_give:
    ; V0.3.0: load optional operand into rax, jump to task epilogue label
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .give_bare_emit
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    jne .give_bare_emit
    cmp byte [r12], 2
    je .give_var
    cmp byte [r12], 5
    je .give_lit
    cmp byte [r12], 6
    je .give_str
    jmp .give_bare_emit
.give_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r12 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .give_jump
.give_str:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    inc rax
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .give_jump
.give_var:
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.give_jump:
    add rcx, 1                      ; park on operand; .text_skip completes (+2 net)
    jmp .give_emit_jmp
.give_bare_emit:
    mov rsi, asm_xor_eax
    mov rdx, len_asm_xor_eax
    call write_to_file
    ; bare give: no advance here - .text_skip supplies the single step
.give_emit_jmp:
    mov rsi, asm_jmp_tret
    mov rdx, len_asm_jmp_tret
    call write_to_file
    mov rax, [cg_ret_label]
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .text_skip

.handle_shift:
    add rcx, 3
    jmp .text_skip
.handle_scan:
    add rcx, 3
    jmp .text_skip
.handle_cycle:
    jmp .text_skip
.handle_mold:
    add rcx, 2
    jmp .text_skip
.handle_forge:
    add rcx, 2
    jmp .text_skip
.handle_view:
    add rcx, 1
    jmp .text_skip
.handle_grab:
    add rcx, 1
    jmp .text_skip
.handle_pull:
    add rcx, 1
    jmp .text_skip
.handle_expose:
    add rcx, 1
    jmp .text_skip
.handle_state:
    add rcx, 2
    jmp .text_skip
.handle_trap:
    add rcx, 1
    jmp .text_skip
.handle_enforce:
    add rcx, 1
    jmp .text_skip

.check_assign:
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .text_skip
    
    cmp byte [r12+1], 2             
    je .emit_task_call

    cmp byte [r12+1], 4             
    je .handle_scalar_assign
    cmp byte [r12+1], 8             
    je .handle_array_assign
    jmp .text_skip

    ret

.handle_scalar_assign:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r13, [token_array + rax]    

    ; --- V0.3.0: RHS is a task call?  dest = fn(args) -> store rax ---
    cmp byte [r13], 2
    jne .hsa_no_call
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .hsa_no_call
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .hsa_no_call
    cmp byte [r12 + 1], 2           ; '(' follows callee ident
    jne .hsa_no_call
    mov rax, rcx
    inc rax                         ; '=' index
    inc rax                         ; callee ident index
    mov rcx, rax                    ; emit_call_sequence expects callee index
    call emit_call_sequence         ; args + call; r11 = ')' index
    mov rcx, r11                    ; parse cursor lands past ')'
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    mov rcx, r11                    ; jump parse cursor past ')'
    jmp .text_skip
.hsa_no_call:

    cmp byte [r13], 1
    jne .check_math
    cmp byte [r13 + 1], 6
    je .emit_sys_assign

.check_math:
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .simple_assign
    shl rax, 4
    lea r8, [token_array + rax]     
    mov edx, [rbx + 4]              
    cmp edx, [r8 + 4]               
    jne .simple_assign              
    
    cmp byte [r8], 3
    jne .simple_assign
    cmp byte [r8 + 1], 6            
    je .arithmetic_assign
    cmp byte [r8 + 1], 7            
    je .arithmetic_assign
    cmp byte [r8 + 1], 16           ; '*'
    je .arithmetic_assign
    cmp byte [r8 + 1], 17           ; '/'
    je .arithmetic_assign
    cmp byte [r8 + 1], 18           ; '%'
    je .arithmetic_assign
    jmp .simple_assign

.simple_assign:
    cmp byte [r13], 5               
    je .emit_literal_assign
    cmp byte [r13], 6               
    je .emit_literal_assign
    cmp byte [r13], 2               
    je .emit_var_assign
    jmp .text_skip

.emit_literal_assign:
    mov rsi, asm_mov1
    mov rdx, len_asm_mov1
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_mov2
    mov rdx, len_asm_mov2
    call write_to_file
    
    cmp byte [r13], 6               
    je .emit_str_ptr
    mov rdi, [r13 + 8]      
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    jmp .emit_lit_end
.emit_str_ptr:
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    add rax, 2
    call write_rax_to_file
.emit_lit_end:
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    add rcx, 2
    jmp .text_skip

.emit_var_assign:
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    add rcx, 2
    jmp .text_skip

.arithmetic_assign:
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .text_skip                  
    shl rax, 4
    lea r9, [token_array + rax]     

    ; --- V0.3.0 fold: x = x + 1 / x = x - 1  ->  inc/dec qword [x] ---
    cmp byte [r13], 2               ; op1 identifier
    jne .no_incdec_fold
    cmp byte [r9], 5                ; op2 numeric literal
    jne .no_incdec_fold
    push rdi
    mov rdi, [r9 + 8]
    mov rdx, kw_one
    call string_compare             ; literal must be exactly "1"
    cmp rax, 1
    pop rdi
    jne .no_incdec_fold
    mov rdi, [rbx + 8]
    mov rdx, [r13 + 8]
    call string_compare             ; op1 must be destination symbol (content compare)
    cmp rax, 1
    jne .no_incdec_fold
    cmp byte [r8 + 1], 6            ; '+' -> inc
    jne .fold_dec_sel
    mov rsi, asm_inc
    mov rdx, len_asm_inc
    jmp .do_fold_write
.fold_dec_sel:
    mov rsi, asm_dec
    mov rdx, len_asm_dec
.do_fold_write:
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    add rcx, 4                      
    jmp .text_skip
.no_incdec_fold:

    cmp byte [r13], 5               
    je .load_op1_lit
    
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .do_op2
.load_op1_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.do_op2:
    cmp byte [r8 + 1], 6            
    je .op_add
    cmp byte [r8 + 1], 7
    je .op_sub
    ; --- V0.3.0: '*','/','%' load op2 into rcx, apply, result in rax ---
    cmp byte [r9], 5                
    je .mdl_op2_lit
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    call write_to_file
    mov rdi, [r9 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .mdl_apply
.mdl_op2_lit:
    mov rsi, asm_mov_rcx_lit
    mov rdx, len_asm_mov_rcx_lit
    call write_to_file
    mov rdi, [r9 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.mdl_apply:
    cmp byte [r8 + 1], 16           ; '*' -> imul
    je .mdl_mul
    mov rsi, asm_div_seq            ; '/' or '%' -> sign-extended idiv
    mov rdx, len_asm_div_seq
    call write_to_file
    cmp byte [r8 + 1], 17           ; '/' -> quotient already in rax
    je .store_dest
    mov rsi, asm_mod_fix            ; '%' -> remainder rdx into rax
    mov rdx, len_asm_mod_fix
    jmp .mdl_write_op
.mdl_mul:
    mov rsi, asm_mul_line
    mov rdx, len_asm_mul_line
.mdl_write_op:
    call write_to_file
    jmp .store_dest
.op_sub:
    cmp byte [r9], 5                
    je .sub_lit
    mov rsi, asm_sub_rax_l
    mov rdx, len_asm_sub_rax_l
    call write_to_file
    jmp .write_op2_var
.sub_lit:
    mov rsi, asm_sub_rax_lit
    mov rdx, len_asm_sub_rax_lit
    call write_to_file
    jmp .write_op2_lit
.op_add:
    cmp byte [r9], 5                
    je .add_lit
    mov rsi, asm_add_rax_l
    mov rdx, len_asm_add_rax_l
    call write_to_file
    jmp .write_op2_var
.add_lit:
    mov rsi, asm_add_rax_lit
    mov rdx, len_asm_add_rax_lit
    call write_to_file
.write_op2_lit:
    mov rdi, [r9 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .store_dest
.write_op2_var:
    mov rdi, [r9 + 8]
    call emit_named_operand         ; V0.3.0 locals aware
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.store_dest:
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    add rcx, 4                      
    jmp .text_skip

.emit_sys_assign:
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r14, [token_array + rax]
    
    cmp byte [r14], 5
    je .sys_a_rax_lit
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r14 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_rdi
.sys_a_rax_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r14 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.sys_a_rdi:
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 5
    je .sys_a_rdi_lit
    mov rsi, asm_mov_rdi_l
    mov rdx, len_asm_mov_rdi_l
    call write_to_file
    mov rdi, [r14 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_rsi
.sys_a_rdi_lit:
    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    call write_to_file
    mov rdi, [r14 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.sys_a_rsi:
    mov rax, rcx
    add rax, 7
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 6
    je .sys_a_rsi_str
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r14 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_a_rdx
.sys_a_rsi_str:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    add rax, 7
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.sys_a_rdx:
    mov rax, rcx
    add rax, 9
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 5
    je .sys_a_rdx_lit
    mov rsi, asm_mov_rdx_l
    mov rdx, len_asm_mov_rdx_l
    call write_to_file
    mov rdi, [r14 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_emit
.sys_a_rdx_lit:
    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    call write_to_file
    mov rdi, [r14 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.sys_a_emit:
    mov rsi, asm_syscall
    mov rdx, len_asm_syscall
    call write_to_file
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    add rcx, 9
    jmp .text_skip

.handle_array_assign:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r14, [token_array + rax]    
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .text_skip
    cmp byte [r12+1], 9             
    jne .text_skip
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .text_skip
    cmp byte [r12+1], 4             
    jne .text_skip
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r13, [token_array + rax]    

    cmp byte [r14], 5
    je .arr_idx_lit
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r14 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .arr_rhs
.arr_idx_lit:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rdi, [r14 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.arr_rhs:
    cmp byte [r13], 5
    je .arr_rhs_lit
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .arr_store
.arr_rhs_lit:
    mov rsi, asm_mov_rcx_lit
    mov rdx, len_asm_mov_rcx_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.arr_store:
    mov rsi, asm_mov1
    mov rdx, len_asm_mov1
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_array_store_2
    mov rdx, len_asm_array_store_2
    call write_to_file
    add rcx, 5
    jmp .text_skip

.text_skip:
    inc rcx
    jmp .text_loop

.text_done:
.empty_cf_stack:
    cmp qword [cf_sp], 0
    je .write_exit
    mov r14, [cf_sp]
    dec r14
    shl r14, 5
    lea r12, [cf_stack + r14]
    
    mov rdi, [r12]
    mov r13, [r12 + 16]             

    cmp r13, 4                      
    je .empty_task_close
    cmp r13, 2
    jne .empty_not_span
    call emit_jmp_start
    jmp .empty_not_when
.empty_task_close:
    mov byte [in_task_flag], 0
    call emit_task_epilogue
    jmp .empty_do_cleanup
.empty_not_span:
    cmp r13, 1
    jne .empty_not_when
    call emit_fallback_label        
.empty_not_when:
    call emit_end_label

.empty_do_cleanup:
    mov r9w, [r12 + 8]
    call emit_scope_cleanup
    dec qword [cf_sp]
    jmp .empty_cf_stack

.write_exit:
    mov rax, 3
    mov rdi, r15
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_gen_done
    mov rdx, len_gen_done
    syscall

.chain_check_entry:
    mov r10, rcx
    inc r10
    cmp r10, [token_count]
    jge .chain_end
    mov rax, r10
    shl rax, 4
    lea r13, [token_array + rax]
    cmp byte [r13], 3
    jne .chain_end
    mov edx, [rbx + 4]
    cmp edx, [r13 + 4]
    jne .chain_end
    movzx r9d, byte [r13 + 1]
    cmp r9b, 6
    je .chain_go
    cmp r9b, 7
    je .chain_go
    cmp r9b, 16
    je .chain_go
    cmp r9b, 17
    je .chain_go
    cmp r9b, 18
    je .chain_go
    jmp .chain_end

.chain_go:
    ; running value in rax; r9b = next operator subtype
    ; consume operator token
    mov r10, rcx
    inc r10                          ; operator token index
    mov rcx, r10
    inc rcx                          ; operand token index
    cmp rcx, [token_count]
    jge .chain_end
    xor r11, r11
    mov r11, rcx                    ; preserve running value? we'll push
    push rax                         ; save running value
    mov rax, rcx
    shl rax, 4
    lea r13, [token_array + rax]
    cmp byte [r13], 5                ; literal
    je .chain_lit
    ; identifier operand
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .chain_have_operand

.chain_lit:
    mov rsi, asm_mov_rcx_lit
    mov rdx, len_asm_mov_rcx_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

.chain_have_operand:
    pop rax                     ; restore running value (rax)
    ; apply operator r9b
    cmp r9b, 16                 ; '*'
    je .chain_mul
    cmp r9b, 17                 ; '/'
    je .chain_div
    cmp r9b, 18                 ; '%'
    je .chain_mod
    cmp r9b, 7                  ; '-'
    je .chain_sub
    ; '+'
    add rax, rcx
    jmp .chain_store
.chain_mul:
    imul rax, rcx
    jmp .chain_store
.chain_div:
    cqo
    idiv rcx
    jmp .chain_store
.chain_mod:
    cqo
    idiv rcx
    mov rax, rdx
    jmp .chain_store
.chain_sub:
    sub rax, rcx
    jmp .chain_store
.chain_add:
    add rax, rcx
    jmp .chain_store
    ; store result into original destination (rbx)
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    mov rcx, r10                 ; cursor at last operand
.chain_store:
    ; store result into original destination (rbx)
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    mov rcx, r10                 ; cursor at last operand
    jmp .chain_check_entry

.chain_end:
    ret

.emit_task_call:
    call emit_call_sequence
    mov rcx, r11
    jmp .text_skip

.out_err:
    mov rax, 1
    mov rdi, 2
    mov rsi, err_out
    mov rdx, err_out_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

; ==============================================================================
; UTILITY & FILE I/O ROUTINES
; ==============================================================================

; ------------------------------------------------------------------------------
; V0.3.0 precompute_frames:
;   Walks the token stream once. For each task, assigns stack slots (rbp
;   displacements) to parameters and body locals, flags them in the symbol
;   table (byte[17]=1, qword[16]=positive byte distance below rbp), and
;   records padded frame sizes in frame_offsets[taskOrdinal].
; ------------------------------------------------------------------------------
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
pf_mark_local:
    push rax
    push rdx
    push rdi
    push rcx
    push r13
    mov r13, rdi                    ; find_symbol contract
    call find_symbol
    cmp rax, 1
    jne .pml_exit
    or byte [rdx + 9], 0x80         ; local flag = subtype bit7
    inc qword [scan_frame_off]
    mov rax, [scan_frame_off]
    shl rax, 3                      ; bytes used so far
    mov [rdx + 16], eax             ; positive distance below rbp (32-bit)
    add rax, 15
    and rax, -16                    ; pad frame to 16 bytes
    mov rdx, [scan_task_id]
    mov [frame_offsets + rdx*8 - 8], rax
.pml_exit:
    pop r13
    pop rcx
    pop rdi
    pop rdx
    pop rax
    ret

; ------------------------------------------------------------------------------
; V0.3.0 emit_named_operand:
;   rdi = identifier string. Writes the plain label text for globals, or
;   "rbp-<offset>" for task-local symbols. Preserves all caller registers.
; ------------------------------------------------------------------------------
emit_named_operand:
    push rax
    push rdi
    push rsi
    push rdx
    push r8
    push r13
    mov r8, rdi                     ; name ptr (find_symbol preserves r8)
    mov r13, rdi
    call find_symbol
    cmp rax, 1
    jne .eno_plain
    test byte [rdx + 9], 0x80
    jz .eno_plain
    push rdx                        ; sym ptr survives everything
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    pop rdx
    mov eax, [rdx + 16]
    call write_rax_to_file
    jmp .eno_exit
.eno_plain:
    mov rdi, r8
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
.eno_exit:
    pop r13
    pop r8
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret
emit_ret:
    push rax
    push rdi
    push rsi
    push rdx
    mov rsi, asm_ret
    mov rdx, len_asm_ret
    call write_to_file
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; V0.3.0: task epilogue - return-value join label + frame teardown
emit_task_epilogue:
    push rax
    push rdi
    push rsi
    push rdx
    mov rsi, asm_tret_label
    mov rdx, len_asm_tret_label
    call write_to_file
    mov rax, [cg_ret_label]
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    mov rsi, asm_epilogue
    mov rdx, len_asm_epilogue
    call write_to_file
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

emit_scope_cleanup:
    push rcx
    push rbx
    push r8
    push rdi
    push rsi
    push rdx
    
    xor r8, r8                      
.cleanup_loop:
    cmp r8, [symbol_count]
    jge .cleanup_done
    mov rax, r8
    shl rax, 5
    lea rbx, [symbol_table + rax]
    mov cx, [rbx + 10]              
    cmp cx, r9w
    jle .skip_cleanup               
    cmp qword [rbx + 24], 0         
    je .skip_cleanup
    cmp byte [rbx + 8], 0           
    je .skip_cleanup

    mov rsi, asm_munmap_1
    mov rdx, len_asm_munmap_1
    call write_to_file
    mov rdi, [rbx]                  
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, asm_munmap_2
    mov rdx, len_asm_munmap_2
    call write_to_file
    mov rdi, [rbx + 24]             
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    
    mov byte [rbx + 8], 0           

.skip_cleanup:
    inc r8
    jmp .cleanup_loop
.cleanup_done:
    pop rdx
    pop rsi
    pop rdi
    pop r8
    pop rbx
    pop rcx
    ret

emit_fallback_label:
    push rdi
    push rax
    mov rsi, asm_l_fallback
    mov rdx, len_asm_l_fallback
    call write_to_file
    mov rax, rdi        
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    pop rax
    pop rdi
    ret

emit_jmp_end:
    push rdi
    push rax
    mov rsi, asm_jmp_l_end
    mov rdx, len_asm_jmp_l_end
    call write_to_file
    mov rax, rdi        
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    pop rax
    pop rdi
    ret

write_rax_to_file:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    mov rcx, 10
    mov rbx, rsp
    dec rsp
    mov byte [rsp], 0
.conv_loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rsp
    mov [rsp], dl
    cmp rax, 0
    jne .conv_loop
    mov rdi, rsp
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsp, rbx
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

emit_start_label:
    push rdi
    push rax
    mov rsi, asm_l_start
    mov rdx, len_asm_l_start
    call write_to_file
    mov rax, rdi        
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    pop rax
    pop rdi
    ret
    
emit_jmp_start:
    push rdi
    push rax
    mov rsi, asm_jmp_l_start
    mov rdx, len_asm_jmp_l_start
    call write_to_file
    mov rax, rdi        
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    pop rax
    pop rdi
    ret

emit_end_label:
    push rdi
    push rax
    mov rsi, asm_l_end
    mov rdx, len_asm_l_end
    call write_to_file
    mov rax, rdi        
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    pop rax
    pop rdi
    ret

write_to_file:
    push rax
    push rdi
    push rcx                
    push r11                
    mov rax, 1              
    mov rdi, r15            
    syscall
    pop r11                 
    pop rcx                 
    pop rdi
    pop rax
    ret

get_strlen:
    push rcx
    push rdi
    xor rax, rax
.len_loop:
    cmp byte [rdi], 0
    je .len_done
    inc rax
    inc rdi
    jmp .len_loop
.len_done:
    pop rdi
    pop rcx
    ret

; ==============================================================================
; SEMANTIC SUBROUTINES
; ==============================================================================
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

add_symbol:
    push rax
    push rbx
    mov rax, [symbol_count]
    shl rax, 5                      
    lea rbx, [symbol_table + rax]
    mov [rbx], r13                  
    mov [rbx + 8], r8b              
    mov [rbx + 9], r9b              
    mov [rbx + 10], r15w            
    mov [rbx + 12], r14d            
    mov eax, [cur_owner]
    mov [rbx + 20], eax             ; V0.3.0 owner task id
    mov qword [rbx + 16], 0         
    mov [rbx + 24], r10             
    inc qword [symbol_count]
    pop rbx
    pop rax
    ret

; ==============================================================================
; LEXER SUBROUTINES
; ==============================================================================
process_current_word:
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
    cmp qword [word_len], 0
    je .end_process

    mov rdi, word_buffer
    mov rcx, [word_len]
    add rdi, rcx
    mov byte [rdi], 0

    call check_numeric
    cmp rax, 1
    je .found_literal

    mov rdi, word_buffer
    mov rdx, kw_lock
    call string_compare
    cmp rax, 1
    je .found_lock
    mov rdi, word_buffer
    mov rdx, kw_flux
    call string_compare
    cmp rax, 1
    je .found_flux
    mov rdi, word_buffer
    mov rdx, kw_task
    call string_compare
    cmp rax, 1
    je .found_task
    mov rdi, word_buffer
    mov rdx, kw_i32
    call string_compare
    cmp rax, 1
    je .found_type_i32
    mov rdi, word_buffer
    mov rdx, kw_str
    call string_compare
    cmp rax, 1
    je .found_type_str
    mov rdi, word_buffer
    mov rdx, kw_raw
    call string_compare
    cmp rax, 1
    je .found_type_raw
    mov rdi, word_buffer
    mov rdx, kw_when
    call string_compare
    cmp rax, 1
    je .found_when
    mov rdi, word_buffer
    mov rdx, kw_span
    call string_compare
    cmp rax, 1
    je .found_span
    mov rdi, word_buffer
    mov rdx, kw_sys
    call string_compare
    cmp rax, 1
    je .found_sys
    mov rdi, word_buffer
    mov rdx, kw_fallback
    call string_compare
    cmp rax, 1
    je .found_fallback
    
    mov rdi, word_buffer
    mov rdx, kw_peek
    call string_compare
    cmp rax, 1
    je .found_peek
    mov rdi, word_buffer
    mov rdx, kw_sysret
    call string_compare
    cmp rax, 1
    je .found_sysret
    mov rdi, word_buffer
    mov rdx, kw_poke
    call string_compare
    cmp rax, 1
    je .found_poke
    mov rdi, word_buffer
    mov rdx, kw_give
    call string_compare
    cmp rax, 1
    je .found_give
    mov rdi, word_buffer
    mov rdx, kw_shift
    call string_compare
    cmp rax, 1
    je .found_shift
    mov rdi, word_buffer
    mov rdx, kw_scan
    call string_compare
    cmp rax, 1
    je .found_scan
    mov rdi, word_buffer
    mov rdx, kw_cycle
    call string_compare
    cmp rax, 1
    je .found_cycle
    mov rdi, word_buffer
    mov rdx, kw_mold
    call string_compare
    cmp rax, 1
    je .found_mold
    mov rdi, word_buffer
    mov rdx, kw_forge
    call string_compare
    cmp rax, 1
    je .found_forge
    mov rdi, word_buffer
    mov rdx, kw_view
    call string_compare
    cmp rax, 1
    je .found_view
    mov rdi, word_buffer
    mov rdx, kw_grab
    call string_compare
    cmp rax, 1
    je .found_grab
    mov rdi, word_buffer
    mov rdx, kw_pull
    call string_compare
    cmp rax, 1
    je .found_pull
    mov rdi, word_buffer
    mov rdx, kw_expose
    call string_compare
    cmp rax, 1
    je .found_expose
    mov rdi, word_buffer
    mov rdx, kw_state
    call string_compare
    cmp rax, 1
    je .found_state
    mov rdi, word_buffer
    mov rdx, kw_trap
    call string_compare
    cmp rax, 1
    je .found_trap
    mov rdi, word_buffer
    mov rdx, kw_enforce
    call string_compare
    cmp rax, 1
    je .found_enforce
    mov rdi, word_buffer
    mov rdx, kw_i8
    call string_compare
    cmp rax, 1
    je .found_i8
    mov rdi, word_buffer
    mov rdx, kw_i16
    call string_compare
    cmp rax, 1
    je .found_i16
    mov rdi, word_buffer
    mov rdx, kw_i64
    call string_compare
    cmp rax, 1
    je .found_i64
    mov rdi, word_buffer
    mov rdx, kw_u8
    call string_compare
    cmp rax, 1
    je .found_u8
    mov rdi, word_buffer
    mov rdx, kw_u16
    call string_compare
    cmp rax, 1
    je .found_u16
    mov rdi, word_buffer
    mov rdx, kw_u32
    call string_compare
    cmp rax, 1
    je .found_u32
    mov rdi, word_buffer
    mov rdx, kw_u64
    call string_compare
    cmp rax, 1
    je .found_u64
    mov rdi, word_buffer
    mov rdx, kw_f32
    call string_compare
    cmp rax, 1
    je .found_f32
    mov rdi, word_buffer
    mov rdx, kw_f64
    call string_compare
    cmp rax, 1
    je .found_f64
    mov rdi, word_buffer
    mov rdx, kw_char
    call string_compare
    cmp rax, 1
    je .found_char
    mov rdi, word_buffer
    mov rdx, kw_bool
    call string_compare
    cmp rax, 1
    je .found_bool

    call save_string
    mov r8b, 2              
    mov r9b, 0              
    mov r10, rax            
    call store_token
    jmp .reset_buffer

.found_literal:
    call save_string
    mov r8b, 5              
    mov r9b, 0
    mov r10, rax
    call store_token
    jmp .reset_buffer
.found_lock:
    mov r8b, 1              
    mov r9b, 1              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_flux:
    mov r8b, 1
    mov r9b, 2              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_task:
    mov r8b, 1
    mov r9b, 3              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_type_i32:
    mov r8b, 4              
    mov r9b, 1              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_type_str:
    mov r8b, 4
    mov r9b, 2              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_type_raw:
    mov r8b, 4
    mov r9b, 3              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_when:
    mov r8b, 1              
    mov r9b, 4              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_span:
    mov r8b, 1              
    mov r9b, 5              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_sys:
    mov r8b, 1              
    mov r9b, 6              
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_fallback:
    mov r8b, 1              
    mov r9b, 7              
    xor r10, r10
    call store_token
    jmp .reset_buffer

.found_peek:
    mov r8b, 1
    mov r9b, 8
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_sysret:
    mov r8b, 1
    mov r9b, 9
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_poke:
    mov r8b, 1
    mov r9b, 10
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_give:
    mov r8b, 1
    mov r9b, 11
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_shift:
    mov r8b, 1
    mov r9b, 12
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_scan:
    mov r8b, 1
    mov r9b, 13
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_cycle:
    mov r8b, 1
    mov r9b, 14
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_mold:
    mov r8b, 1
    mov r9b, 15
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_forge:
    mov r8b, 1
    mov r9b, 16
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_view:
    mov r8b, 1
    mov r9b, 17
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_grab:
    mov r8b, 1
    mov r9b, 18
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_pull:
    mov r8b, 1
    mov r9b, 19
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_expose:
    mov r8b, 1
    mov r9b, 20
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_state:
    mov r8b, 4
    mov r9b, 15
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_trap:
    mov r8b, 1
    mov r9b, 22
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_enforce:
    mov r8b, 1
    mov r9b, 23
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_i8:
    mov r8b, 4
    mov r9b, 4
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_i16:
    mov r8b, 4
    mov r9b, 5
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_i64:
    mov r8b, 4
    mov r9b, 6
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_u8:
    mov r8b, 4
    mov r9b, 7
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_u16:
    mov r8b, 4
    mov r9b, 8
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_u32:
    mov r8b, 4
    mov r9b, 9
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_u64:
    mov r8b, 4
    mov r9b, 10
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_f32:
    mov r8b, 4
    mov r9b, 11
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_f64:
    mov r8b, 4
    mov r9b, 12
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_char:
    mov r8b, 4
    mov r9b, 13
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_bool:
    mov r8b, 4
    mov r9b, 14
    xor r10, r10
    call store_token
    jmp .reset_buffer

.reset_buffer:
    mov qword [word_len], 0
.end_process:
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

check_numeric:
    push rsi
    push rcx
    mov rsi, word_buffer
    mov rcx, [word_len]
    cmp rcx, 0
    je .not_num
    ; V0.3.0: optional leading '-' (negative literals)
    cmp byte [rsi], '-'
    jne .num_scan
    inc rsi
    dec rcx
.num_scan:
    cmp rcx, 0                      ; "-" alone is not numeric
    je .not_num
.num_loop:
    mov al, [rsi]
    cmp al, '0'
    jl .not_num
    cmp al, '9'
    jg .not_num
    inc rsi
    dec rcx
    jnz .num_loop
    mov rax, 1
    pop rcx
    pop rsi
    ret
.not_num:
    mov rax, 0
    pop rcx
    pop rsi
    ret

store_token:
    push rax
    push rbx
    push rcx
    mov rax, [token_count]
    shl rax, 4                      
    lea rbx, [token_array + rax]    
    mov [rbx], r8b
    mov [rbx + 1], r9b
    mov cx, [current_indent]
    mov [rbx + 2], cx
    mov ecx, [current_line]
    mov [rbx + 4], ecx
    mov [rbx + 8], r10
    mov [last_token_type], r8b      ; V0.3.0 track for unary-minus detection
    inc qword [token_count]
    pop rcx
    pop rbx
    pop rax
    ret

save_string:
    push rsi
    push rdi
    push rcx
    push rbx
    mov rsi, word_buffer
    mov rbx, [pool_offset]
    lea rdi, [string_pool + rbx]
    mov rax, rdi            
    mov rcx, [word_len]
    inc rcx                 
.copy_loop:
    mov dl, [rsi]
    mov [rdi], dl
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_loop
    mov rcx, [word_len]
    inc rcx
    add [pool_offset], rcx
    pop rbx
    pop rcx
    pop rdi
    pop rsi
    ret

string_compare:
    push rcx
    push rbx
    push rdi
    push rdx
.compare_loop:
    mov bl, byte [rdi]
    mov cl, byte [rdx]
    cmp bl, 0
    jne .check_chars
    cmp cl, 0
    je .match
.check_chars:
    cmp bl, cl
    jne .no_match
    inc rdi
    inc rdx
    jmp .compare_loop
.no_match:
    mov rax, 0
    pop rdx
    pop rdi
    pop rbx
    pop rcx
    ret
.match:
    mov rax, 1
    pop rdx
    pop rdi
    pop rbx
    pop rcx
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