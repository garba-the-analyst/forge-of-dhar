; ==============================================================================
; THE FORGE OF DHAR (V0.1.2 ARCHITECTURE)
; Final Pre-Bootstrapped x86_64 Native Systems Compiler
; Author: Abdullahi Baba Garba (Garba the Analyst)
; ==============================================================================

section .data
    usage_msg db "Usage: ./build/dharc <source_file.dhar>", 10, 0
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

    asm_munmap_1 db "    ; --- Scope Cleanup (Neutered for V0) ---", 10, "    ; mov rax, 11", 10, "    ; mov rdi, "
    len_asm_munmap_1 equ $ - asm_munmap_1
    asm_munmap_2 db 10, "    ; mov rsi, "
    len_asm_munmap_2 equ $ - asm_munmap_2
    
    newline db 10

section .bss
    token_array resb 65536         
    token_count resq 1              
    string_pool resb 65536          
    pool_offset resq 1
    symbol_table resb 65536         
    symbol_count resq 1
    cf_stack resb 8192              
    cf_sp resq 1                    
    label_id_counter resq 1         
    file_buffer resb 4096           
    word_buffer resb 1024           
    word_len resq 1
    is_line_start resb 1
    indent_count resw 1             
    current_indent resw 1
    current_line resd 1

section .text
    global _start

_start:
    mov rbx, [rsp]                  
    cmp rbx, 2                      
    jl .print_usage
    mov r12, [rsp + 16]             

    mov dword [current_line], 1
    mov word [indent_count], 0
    mov word [current_indent], 0
    mov qword [token_count], 0
    mov qword [symbol_count], 0
    mov qword [pool_offset], 0
    mov byte [is_line_start], 1
    mov qword [cf_sp], 0
    mov qword [label_id_counter], 1

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
    mov rdx, 4096           
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
    jmp .next_token

; --- NEW STAGE 1 PARSER SKIPS (Fixed Off-By-One) ---
.check_peek_stmt:
    add rcx, 5
    jmp .next_token
.check_sysret_stmt:
    add rcx, 1
    jmp .next_token

.check_fallback_stmt:
    add rcx, 1                      
    jmp .next_token
.check_cf_stmt:
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
    call check_symbol_collision
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
    add rcx, 2                      
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

run_codegen:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_gen_start
    mov rdx, len_gen_start
    syscall

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
    call emit_ret                   
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
    jmp .text_skip

.handle_peek:
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r12, [token_array + rax] 
    
    mov rsi, asm_peek_1
    mov rdx, len_asm_peek_1
    call write_to_file
    mov rdi, [r12 + 8] 
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    
    mov rsi, asm_peek_2
    mov rdx, len_asm_peek_2
    call write_to_file

    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax] 
    
    mov rdi, [r12 + 8] 
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file

    mov rsi, asm_peek_3
    mov rdx, len_asm_peek_3
    call write_to_file

    mov rax, rcx
    add rax, 1
    shl rax, 4
    lea r12, [token_array + rax] 
    
    mov rdi, [r12 + 8] 
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file

    mov rsi, asm_peek_4
    mov rdx, len_asm_peek_4
    call write_to_file

    add rcx, 5          ; FIX: Was 6. Prevents off-by-one skip!
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    
    mov rsi, asm_sysret_2
    mov rdx, len_asm_sysret_2
    call write_to_file
    
    add rcx, 1          ; FIX: Was 2. Prevents off-by-one skip!
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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

    mov r14, [cf_sp]
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov qword [r11], 0
    mov dx, [rbx + 2]               
    mov [r11 + 8], dx
    mov qword [r11 + 16], 4         
    inc qword [cf_sp]
    
.skip_task_tokens:
    inc rcx
    mov rax, rcx
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3               
    jne .skip_task_tokens
    cmp byte [r12 + 1], 1           
    jne .skip_task_tokens
    jmp .text_skip

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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
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
    
    cmp byte [rbx + 1], 4
    je .emit_jne_fallback
    mov rsi, asm_jne_l_end
    mov rdx, len_asm_jne_l_end
    jmp .do_jne_write
.emit_jne_fallback:
    mov rsi, asm_jne_l_fallback
    mov rdx, len_asm_jne_l_fallback
.do_jne_write:
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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

    ; --- FIX: Raw Pointer Check ---
    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rdi_normal
    cmp byte [rdx + 8], 3      ; Is it a raw[] array?
    je .sys_rdi_lit            ; If yes, load its bare address!
.sys_rdi_normal:
    mov rsi, asm_mov_rdi_l
    mov rdx, len_asm_mov_rdi_l
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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

    ; --- FIX: Raw Pointer Check ---
    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rsi_normal
    cmp byte [rdx + 8], 3      ; Is it a raw[] array?
    je .sys_rsi_lit            ; If yes, load its bare address!
.sys_rsi_normal:
    mov rsi, asm_mov_rsi_l
    mov rdx, len_asm_mov_rsi_l
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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

    ; --- FIX: Raw Pointer Check ---
    push r13
    mov r13, [r13 + 8]
    call find_symbol
    pop r13
    cmp rax, 1
    jne .sys_rdx_normal
    cmp byte [rdx + 8], 3      ; Is it a raw[] array?
    je .sys_rdx_lit            ; If yes, load its bare address!
.sys_rdx_normal:
    mov rsi, asm_mov_rdx_l
    mov rdx, len_asm_mov_rdx_l
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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

.emit_task_call:
    mov rsi, asm_call
    mov rdx, len_asm_call
    call write_to_file
    mov rdi, [rbx + 8]              
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    add rcx, 2                      
    jmp .text_skip

.handle_scalar_assign:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .text_skip
    shl rax, 4
    lea r13, [token_array + rax]    

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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]              
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    cmp byte [r13], 5               
    je .load_op1_lit
    
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.store_dest:
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
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
    call emit_ret
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
    ret

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