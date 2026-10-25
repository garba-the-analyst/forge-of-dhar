; tokenize.asm - character scanning, token creation (StageAlpha 3)
section .text

tokenize_source:                    ; scan file_buffer, emit tokens; returns at EOF

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
    cmp rcx, 4095                  ; Phase 1.5b: cap 4095 keeps NUL in bounds
    jae fatal_full
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
    cmp rcx, 4095                  ; Phase 1.5b: cap 4095 keeps NUL in bounds
    jae fatal_full
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
    cmp rcx, 4095                  ; Phase 1.5b: cap 4095 keeps NUL in bounds
    jae fatal_full
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
    je .quote_bad
    cmp al, 34                  
    je .quote_done
    mov rcx, [word_len]
    cmp rcx, 4095                  ; Phase 1.5b: cap 4095 keeps NUL in bounds
    jae fatal_full
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

.quote_bad:
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

    ret


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

    ; bool literals: `true`/`false` are numeric 1/0 (Spec1 §2). The words are
    ; reserved and never identifiers: rewrite the buffer so the shared numeric
    ; path below stores them (all condition/init validation keys on type 5).
    mov rdi, word_buffer
    mov rdx, kw_true
    call string_compare
    cmp rax, 1
    jne .not_bool_true
    mov byte [word_buffer], '1'
    mov byte [word_buffer + 1], 0
    mov qword [word_len], 1
    mov byte [bool_lit_flag], 1     ; Phase 3: remember it was written true (gen prints "true")
.not_bool_true:
    mov rdi, word_buffer
    mov rdx, kw_false
    call string_compare
    cmp rax, 1
    jne .not_bool_false
    mov byte [word_buffer], '0'
    mov byte [word_buffer + 1], 0
    mov qword [word_len], 1
    mov byte [bool_lit_flag], 1     ; Phase 3: remember it was written false
.not_bool_false:

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
    mov rdx, kw_gen
    call string_compare
    cmp rax, 1
    je .found_gen
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
    mov rdx, kw_escape
    call string_compare
    cmp rax, 1
    je .found_escape
    mov rdi, word_buffer
    mov rdx, kw_skip
    call string_compare
    cmp rax, 1
    je .found_skip
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
    movzx r9d, byte [bool_lit_flag] ; Phase 3: subtype 1 = the literal was written true/false, else 0
    mov byte [bool_lit_flag], 0
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
.found_gen:
    mov r8b, 1
    mov r9b, 25
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
.found_escape:
    mov r8b, 1
    mov r9b, 26
    xor r10, r10
    call store_token
    jmp .reset_buffer
.found_skip:
    mov r8b, 1
    mov r9b, 27
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
    cmp rax, 65536                  ; Phase 1.5b: token_array holds 65536
    jae fatal_full
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
    mov rax, [pool_offset]          ; Phase 1.5b: string_pool holds 1MB
    add rax, [word_len]
    inc rax                         ; trailing NUL
    cmp rax, 1048576
    ja fatal_full
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

