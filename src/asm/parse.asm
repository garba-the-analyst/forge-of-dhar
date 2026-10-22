; parse.asm - recursive-descent parsing per StageAlpha 2.2
section .text

parse_cf_push:
    push rax
    push rbx
    mov rax, [parse_cf_depth]
    cmp rax, 256
    jae fatal_full
    mov [parse_cf_indent + rax*2], dx
    mov [parse_cf_kind + rax], r11b
    inc qword [parse_cf_depth]
    pop rbx
    pop rax
    ret
parse_cf_pop_ge:                    ; pop while top.indent >= dx
    push rax
    push rbx
.ppg_loop:
    mov rax, [parse_cf_depth]
    test rax, rax
    jz .ppg_done
    dec rax
    movzx ebx, word [parse_cf_indent + rax*2]
    cmp bx, dx
    jb .ppg_done
    dec qword [parse_cf_depth]
    jmp .ppg_loop
.ppg_done:
    pop rbx
    pop rax
    ret
parse_cf_pop_gt:                    ; pop while top.indent > dx
    push rax
    push rbx
.ppg2_loop:
    mov rax, [parse_cf_depth]
    test rax, rax
    jz .ppg2_done
    dec rax
    movzx ebx, word [parse_cf_indent + rax*2]
    cmp bx, dx
    jbe .ppg2_done
    dec qword [parse_cf_depth]
    jmp .ppg2_loop
.ppg2_done:
    pop rbx
    pop rax
    ret

run_parser:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_parsing
    mov rdx, len_parsing
    syscall
    xor rcx, rcx                    

.parse_loop:
    cmp rcx, [token_count]
    jge .parse_eof_check
.parse_body:
    mov rax, rcx
    shl rax, 4                      
    lea rbx, [token_array + rax]    
    mov r8b, [rbx]                  
    mov r9b, [rbx + 1]              
    cmp r8b, 1                      
    je .check_keyword
    cmp r8b, 2                      
    je .check_identifier
    ; Phase 1.6: brace tracking for mold bodies (operators fall through here)
    cmp r8b, 3
    jne .next_token
    cmp r9b, 19                     ; '{'
    je .brace_open
    cmp r9b, 20                     ; '}'
    jne .next_token
    cmp qword [parse_brace_depth], 0
    je .err_shape                   ; unbalanced '}'
    dec qword [parse_brace_depth]
    ; Closing a mold body finalizes its recorded layout size.
    mov rax, [mold_open]
    test rax, rax
    jz .brace_no_mold
    dec rax
    mov rdx, [mold_cur_off]
    mov [mold_sizes + rax*8], rdx
    mov qword [mold_open], 0
.brace_no_mold:
    jmp .next_token
.brace_open:
    inc qword [parse_brace_depth]
    jmp .next_token

.check_keyword:
    ; Phase 1.6: inside { } (mold bodies) only field declarations exist;
    ; any other keyword there is invalid (fields are lock/flux lines only)
    cmp qword [parse_brace_depth], 0
    je .ck_nobrace
    cmp r9b, 1
    je .ck_nobrace
    cmp r9b, 2
    je .ck_nobrace
    jmp .err_subset
.ck_nobrace:
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
    cmp r9b, 25                     ; gen
    je .check_gen_stmt
    cmp r9b, 12                     ; shift: else-if chain link
    je .check_shift_stmt
    cmp r9b, 13                     ; scan: value-iteration loop
    je .check_scan_stmt
    cmp r9b, 14                     ; cycle: infinite loop
    je .check_cycle_stmt
    cmp r9b, 15                     ; mold: layout declaration (see .check_mold_stmt)
    je .check_mold_stmt
    cmp r9b, 16                     ; forge: not in subset
    je .err_subset
    cmp r9b, 17                     ; view: not in subset
    je .err_subset
    cmp r9b, 18                     ; grab: not in subset
    je .err_subset
    cmp r9b, 19                     ; pull: module directive (single-file: binds nothing)
    je .check_pull_stmt
    cmp r9b, 20                     ; expose: publishes a declared name
    je .check_expose_stmt
    cmp r9b, 21                     ; state
    je .check_state_stmt
    cmp r9b, 22                     ; trap: not in subset
    je .err_subset
    cmp r9b, 23                     ; enforce: not in subset
    je .err_subset
    cmp r9b, 26                     ; escape: break nearest loop
    je .check_escape_stmt
    cmp r9b, 27                     ; skip: continue nearest loop
    je .check_escape_stmt           ; (same validation as escape)
    jmp .next_token

.check_peek_stmt:
    ; Phase 1.5c: peek dst, buf, idx — full shape + raw-buffer validation.
    ; rbx = peek token (line source for syntax errors); r14d set for semantics.
    mov r14d, [rbx + 4]
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; dst identifier?
    jne .err_shape
    push r12
    mov rdi, [r12 + 8]
    call find_symbol_scoped
    pop r12
    cmp rax, 1
    jne .err_undeclared
    cmp byte [rdx + 8], 1           ; lock target?
    je .err_immutable
    cmp byte [rdx + 8], 2           ; flux scalar?
    je .peek_dst_ok
    cmp byte [rdx + 8], 5           ; parameter slot?
    jne .err_shape
.peek_dst_ok:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10          ; ','?
    jne .err_shape
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; buf identifier?
    jne .err_shape
    push r12
    mov rdi, [r12 + 8]
    call find_symbol_scoped
    pop r12
    cmp rax, 1
    jne .err_undeclared
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .err_index
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .peek_done
    cmp byte [r12], 5
    jne .err_shape
.peek_done:
    add rcx, 5
    jmp .next_token
.check_poke_stmt:
    ; Phase 1.5c: poke buf, idx, val — full shape + raw-buffer validation.
    mov r14d, [rbx + 4]
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; buf identifier?
    jne .err_shape
    push r12
    mov rdi, [r12 + 8]
    call find_symbol_scoped
    pop r12
    cmp rax, 1
    jne .err_undeclared
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .err_index
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .poke_done
    cmp byte [r12], 5
    jne .err_shape
.poke_done:
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    jne .poke_not_ident
    ; identifier values must resolve to a plain scalar (same rule as stores)
    push rbx
    push rcx
    push r12
    push rdx
    mov rdi, [r12 + 8]
    call find_symbol_scoped
    cmp rax, 1
    jne .poke_val_undecl
    cmp byte [rdx + 8], 3
    je .poke_val_bad
    cmp byte [rdx + 8], 11
    je .poke_val_bad
    cmp byte [rdx + 8], 12
    je .poke_val_bad
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .poke_val_ok
.poke_val_undecl:
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .err_undeclared
.poke_val_bad:
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .err_expr
.poke_not_ident:
    cmp byte [r12], 5
    je .poke_val_ok
    jmp .err_shape
.poke_val_ok:
    add rcx, 5                      ; poke buf, idx, val -> 6 tokens total
    jmp .next_token

.check_give_stmt:
    ; V0.3.0: 'give' optionally carries one same-line operand.
    ; Phase 2 (give fix): the operand may be followed by one binary operator and a second
    ; operand (give a + b). Anything else on the line is rejected instead of silently dropped.
    ; Accounting: leave rcx on LAST consumed token; .next_token supplies the
    ; final increment (bare = net 1, with operand = net 2, with a op b = net 4).
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
    cmp byte [r12], 6               ; string literal: consumed by the later token walk
    je .next_token
    cmp byte [r12], 3               ; '-' followed by a number is a negative literal (give -1)
    jne .err_shape
    cmp byte [r12 + 1], 7
    jne .err_shape
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    jne .err_shape
    cmp byte [r12], 5
    jne .err_shape
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .give_neg_ok
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    je .err_shape                   ; extra tokens after '-N'
.give_neg_ok:
    add rcx, 2                      ; park on the number; .next_token supplies the last step
    jmp .next_token
.check_give_operand_ok:
    ; reject calls as return values for now (ident followed by '(')
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .give_consume_operand
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    jne .give_consume_operand       ; next token is on the next line: done
    cmp byte [r12], 3
    jne .err_shape                  ; 'give a b': stray token
    cmp byte [r12 + 1], 2           ; '(' -> unsupported call-return
    je .err_give_call
    cmp byte [r12 + 1], 6           ; + - * / %
    je .give_tail
    cmp byte [r12 + 1], 7
    je .give_tail
    cmp byte [r12 + 1], 16
    je .give_tail
    cmp byte [r12 + 1], 17
    je .give_tail
    cmp byte [r12 + 1], 18
    je .give_tail
    jmp .err_shape
.give_tail:
    ; second operand: identifier or number, on the same line, nothing after it
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    jne .err_shape
    cmp byte [r12], 2
    je .give_tail_end
    cmp byte [r12], 5
    jne .err_shape
.give_tail_end:
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .give_consume_tail
    shl rax, 4
    lea r12, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r12 + 4]
    je .err_shape                   ; extra tokens after 'a op b'
.give_consume_tail:
    add rcx, 3                      ; park on the second operand
    jmp .next_token
.give_consume_operand:
    add rcx, 1                      ; point at operand
    jmp .next_token

.err_give_call:
    mov rsi, msg_err_syntax
    mov rdx, len_err_syntax
    jmp .print_syntax_err
.check_gen_stmt:
    ; gen("string") or gen(expr) - consume opening paren, string/expr, closing paren
    add rcx, 3
    jmp .next_token
.check_shift_stmt:
    ; Phase 1.6: shift <ident> <cmp-op> <value> ':' — else-if, may repeat.
    ; Same shape as when, plus chain validation: pop deeper blocks, then
    ; the head at this indent must be an unconsumed when/shift link.
    ; The head is replaced by the new shift link (codegen mirrors this).
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; LHS identifier?
    jne .err_bad_condition
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_bad_condition
    mov r11b, [r12 + 1]
    cmp r11b, 5
    je .shift_op_valid
    cmp r11b, 11
    jb .err_bad_condition
    cmp r11b, 15
    ja .err_bad_condition
.shift_op_valid:
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_bad_condition
    ; Same RHS rule as when/span: identifier or number only (see .cond_op_valid).
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .shift_rhs_ok
    cmp byte [r12], 5
    jne .err_cond_rhs
.shift_rhs_ok:
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_bad_condition
    cmp byte [r12 + 1], 1           ; ':'?
    jne .err_bad_condition
    mov dx, [rbx + 2]
    call parse_cf_pop_gt             ; pop deeper blocks only
    mov rax, [parse_cf_depth]
    test rax, rax
    jz .err_orphan
    dec rax
    movzx r10d, word [parse_cf_indent + rax*2]
    cmp r10w, dx
    jne .err_orphan
    mov r10b, [parse_cf_kind + rax]
    cmp r10b, 1
    je .shift_head_ok
    cmp r10b, 5
    jne .err_orphan
.shift_head_ok:
    dec qword [parse_cf_depth]       ; pop the head link
    mov dx, [rbx + 2]
    mov r11b, 5
    call parse_cf_push               ; push the new shift link
    add rcx, 4
    jmp .next_token
.check_scan_stmt:
    ; Phase 1.6.2: scan x in buf ':' — value-iteration over a raw buffer.
    ; rbx = scan token. Declares x (fresh flux i32) in the current scope.
    mov r14d, [rbx + 4]             ; line for semantic diagnostics
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; x identifier?
    jne .err_shape
    mov r13, [r12 + 8]
    call check_symbol_collision_scoped
    cmp rax, 1
    je .err_redeclared              ; Dhar has no shadowing
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; contextual 'in'?
    jne .err_shape
    push rbx
    push rcx
    push r12
    mov rdi, [r12 + 8]
    mov rdx, kw_in_soft
    call string_compare
    cmp rax, 1
    pop r12
    pop rcx
    pop rbx
    jne .err_shape
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; buf identifier?
    jne .err_shape
    push r12
    mov rdi, [r12 + 8]
    call find_symbol_scoped
    pop r12
    cmp rax, 1
    jne .err_undeclared
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3                       ; buf must be raw (bound comes from it)
    jne .err_index
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 1           ; ':'?
    jne .err_shape
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    mov dx, [rbx + 2]
    cmp dx, [r12 + 2]               ; non-empty body?
    jge .err_shape
    ; register x as a flux i32 local in this scope
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]
    mov r13, [r12 + 8]              ; x name
    mov r8b, 2                      ; flux
    mov r9b, 1                      ; i32
    xor r10, r10                    ; scalar
    mov r14d, [rbx + 4]             ; (re-set: helpers may use r14d)
    mov r15w, [rbx + 2]
    call add_symbol
    ; block-stack: pop closed siblings, push the scan link
    mov dx, [rbx + 2]
    call parse_cf_pop_ge
    mov r11b, 7
    call parse_cf_push
    add rcx, 4
    jmp .next_token
.check_cycle_stmt:
    ; Phase 1.6.2: cycle ':' — infinite loop, exits only via escape.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 1           ; ':'?
    jne .err_shape
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    mov dx, [rbx + 2]
    cmp dx, [r12 + 2]               ; non-empty body (else hangs forever)
    jge .err_shape
    mov dx, [rbx + 2]
    call parse_cf_pop_ge
    mov r11b, 6
    call parse_cf_push
    add rcx, 1
    jmp .next_token
.check_escape_stmt:
    ; Phase 1.6.2: escape/skip need a strictly enclosing loop. The stack
    ; is only peeked (no mutation): nearest loop frame below this line wins.
    mov dx, [rbx + 2]
    mov rax, [parse_cf_depth]
.esc_scan:
    test rax, rax
    jz .err_orphan
    dec rax
    mov r10b, [parse_cf_kind + rax]
    cmp r10b, 2
    je .esc_found
    cmp r10b, 6
    je .esc_found
    cmp r10b, 7
    je .esc_found
    jmp .esc_scan
.esc_found:
    movzx r10d, word [parse_cf_indent + rax*2]
    cmp r10w, dx
    jae .err_orphan                 ; loop must strictly contain this line
    jmp .next_token
.check_mold_stmt:
    ; `mold Name {` — layout declaration (StageAlpha §2.2, layout only).
    ; Registers the type in the mold table (separate type namespace) and opens
    ; it for field recording. Emits nothing (codegen skips the block).
    ; rbx = mold token.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; mold name ident?
    jne .err_shape
    mov rdi, [r12 + 8]
    call .find_mold                 ; rax = 1-based idx, 0 = missing
    cmp rax, 0
    jne .err_redeclared             ; mold types cannot be redeclared
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 8           ; '[' (generics `mold P[T]`)?
    je .err_subset                  ; generics are not subset
    cmp byte [r12 + 1], 19          ; '{'?
    jne .err_shape
    mov rax, [mold_count]
    cmp rax, 64
    jae fatal_full
    mov rdx, rcx                    ; reload mold name ptr (r12 was reused)
    inc rdx
    shl rdx, 4
    lea r12, [token_array + rdx]
    mov r13, [r12 + 8]
    mov [mold_names + rax*8], r13
    mov qword [mold_sizes + rax*8], 0
    mov qword [mold_fcounts + rax*8], 0
    inc qword [mold_count]
    inc rax
    mov [mold_open], rax            ; 1-based open mold
    mov qword [mold_cur_off], 0
    add rcx, 1                      ; consume `mold` (Name + `{` dispatch next:
                                    ; Name validates below, `{` counts depth)
    jmp .next_token

; .find_mold: rdi = NUL-terminated name → rax = 1-based mold idx, 0 = missing.
; Preserves rbx, rcx, rdi, rsi. Local to run_parser (a global here would
; re-anchor every parser label below it and break the build).
.find_mold:
    push rbx
    push rcx
    push rdx
    push r8
    xor r8, r8
.fm_loop:
    cmp r8, [mold_count]
    jge .fm_fail
    mov rdx, [mold_names + r8*8]
    call string_compare             ; (rdi, rdx); keeps rbx/rcx/rdi/rdx
    cmp rax, 1
    je .fm_hit
    inc r8
    jmp .fm_loop
.fm_fail:
    xor rax, rax
    jmp .fm_exit
.fm_hit:
    mov rax, r8
    inc rax
.fm_exit:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

.check_mold_field:
    ; lock/flux name : TYPE inside an open mold — layout recording only.
    ; No symbols are created and no code is emitted. No defaults, no
    ; nested-mold/generic types. Consumes through the type (or `]`).
    ; rbx = lock/flux token.
    mov rax, rcx
    inc rax                         ; field name
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    jne .err_shape
    mov rax, rcx
    add rax, 2                      ; ':'
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 1
    jne .err_shape
    mov rax, rcx
    add rax, 3                      ; type
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 4               ; primitive type?
    jne .err_subset                 ; nested-mold types defer to Beta
    mov r10b, [r12 + 1]
    cmp r10b, 1                     ; i32
    je .mf_scalar
    cmp r10b, 2                     ; str
    je .mf_scalar
    cmp r10b, 14                    ; bool
    je .mf_scalar
    cmp r10b, 3                     ; raw: sized [N] or bare (1 slot)
    jne .err_subset                 ; other widths + state: not subset
    mov rax, rcx                    ; raw: '[' or '=' or end?
    add rax, 4
    cmp rax, [token_count]
    jge .mf_bare_raw
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .mf_bare_raw
    cmp byte [r12 + 1], 8           ; '['?
    je .mf_raw_sized
    cmp byte [r12 + 1], 4           ; '=' default?
    je .err_subset                  ; field defaults are not subset
.mf_bare_raw:
    mov r10, 1
    jmp .mf_record_consume3
.mf_scalar:
    mov rax, rcx                    ; '=' default?
    add rax, 4
    cmp rax, [token_count]
    jge .mf_scalar_noinit
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .mf_scalar_noinit
    cmp byte [r12 + 1], 4
    je .err_subset                  ; field defaults are not subset
.mf_scalar_noinit:
    mov r10, 1
.mf_record_consume3:
    shl r10, 3
    add [mold_cur_off], r10
    mov rax, [mold_open]
    dec rax
    inc qword [mold_fcounts + rax*8]
    add rcx, 3                      ; consume kw..type
    jmp .next_token
.mf_raw_sized:
    mov rax, rcx                    ; number
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 5
    jne .err_shape
    mov rax, rcx                    ; ']'
    add rax, 6
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 9
    jne .err_shape
    mov rax, rcx                    ; '=' default?
    add rax, 7
    cmp rax, [token_count]
    jge .mf_raw_noinit
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .mf_raw_noinit
    cmp byte [r12 + 1], 4
    je .err_subset                  ; field defaults are not subset
.mf_raw_noinit:
    mov rax, rcx                    ; size digits at rcx+5
    add rax, 5
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call parse_uint                 ; rax = N; preserves rbx/rcx/rdi
    mov r10, rax
    add r10, 7
    shr r10, 3                      ; slots = ceil(N/8)
    test r10, r10
    jnz .mf_raw_slots
    mov r10, 1                      ; degenerate raw[0]: one slot floor
.mf_raw_slots:
    shl r10, 3
    add [mold_cur_off], r10
    mov rax, [mold_open]
    dec rax
    inc qword [mold_fcounts + rax*8]
    add rcx, 6                      ; consume kw..']'
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
    ; `pull <ident|string>` — module directive. The bridge links exactly one
    ; file, so the directive binds nothing (real modules are Beta); the shape
    ; is validated and the operand consumed. rbx = pull token.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; module name ident?
    je .pull_ok
    cmp byte [r12], 6               ; ...or quoted name?
    jne .err_shape
.pull_ok:
    add rcx, 1
    jmp .next_token
.check_expose_stmt:
    ; `expose <ident>` — publishes a name from this file. The operand must be
    ; a declared symbol (task or variable); the bridge records nothing beyond
    ; the check (single-file link unit). rbx = expose token.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; name ident?
    jne .err_shape
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; cur_owner live; preserves rbx/rcx
    cmp rax, 1
    jne .err_undeclared
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
    ; Phase 1.6: fallback needs a when/shift head at the same indent.
    ; The head is marked consumed (kind 3): a later shift/fallback here
    ; is an orphan. The frame itself pops on dedent.
    mov dx, [rbx + 2]
    call parse_cf_pop_gt
    mov rax, [parse_cf_depth]
    test rax, rax
    jz .err_orphan
    dec rax
    movzx r10d, word [parse_cf_indent + rax*2]
    cmp r10w, dx
    jne .err_orphan
    mov r10b, [parse_cf_kind + rax]
    cmp r10b, 1
    je .fb_head_ok
    cmp r10b, 5
    jne .err_orphan
.fb_head_ok:
    mov byte [parse_cf_kind + rax], 3
    add rcx, 1
    jmp .next_token
.check_cf_stmt:
    ; Condition grammar: [when|span] [identifier] [cmp-op] [value] ':'
    ; Valid operators: '=='(5), '<'(11), '>'(12), '<='(13), '>='(14), '!='(15)
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; Phase 1.6: LHS must be an identifier
    jne .err_bad_condition
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
    ; Stage 0 conditions compare identifier vs number/variable only: a string
    ; (or any other) RHS used to fall through and miscompile as
    ; `cmp rax, "lit"` (NASM expression error). Reject with a diagnostic.
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2               ; RHS identifier?
    je .cond_rhs_ok
    cmp byte [r12], 5               ; RHS number?
    jne .err_cond_rhs
.cond_rhs_ok:
    ; Phase 1.6: trailing ':' required (Spec1 2.5: ':' opens the block)
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_bad_condition
    cmp byte [r12 + 1], 1           ; ':'?
    jne .err_bad_condition
    ; Phase 1.6: span needs a non-empty body (an empty loop hangs forever)
    cmp r9b, 5                      ; span?
    jne .cf_no_body_check
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_bad_condition
    shl rax, 4
    lea r12, [token_array + rax]
    mov dx, [rbx + 2]
    cmp dx, [r12 + 2]               ; body indent deeper?
    jge .err_bad_condition
.cf_no_body_check:
    ; Phase 1.6: block-stack tracking (pop closed siblings, push opener)
    mov dx, [rbx + 2]
    call parse_cf_pop_ge
    mov r11b, 1                     ; when
    cmp r9b, 4
    je .cf_push_done
    mov r11b, 2                     ; span
.cf_push_done:
    call parse_cf_push
    add rcx, 4
    jmp .next_token
.check_sys_stmt:
    ; Phase 1.5c: sys nr, a1, a2, a3 — comma shape + operand kinds.
    ; nr/a1/a3 ∈ {ident, number}; a2 ∈ {ident, number, string}.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sys_nr_ok
    cmp byte [r12], 5
    jne .err_shape
.sys_nr_ok:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sys_a1_ok
    cmp byte [r12], 5
    jne .err_shape
.sys_a1_ok:
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sys_a2_ok
    cmp byte [r12], 5
    je .sys_a2_ok
    cmp byte [r12], 6
    jne .err_shape
.sys_a2_ok:
    mov rax, rcx
    add rax, 6
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 7
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sys_done
    cmp byte [r12], 5
    jne .err_shape
.sys_done:
    add rcx, 7
    jmp .next_token

.check_task_decl:
    ; Phase 1.6: tasks open a block frame (pop closed siblings, push task)
    mov dx, [rbx + 2]
    call parse_cf_pop_ge
    mov r11b, 4
    call parse_cf_push
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
    mov r11b, [r12 + 1]              ; base type (i32=1, str=2, raw=3)
    cmp r11b, 1                     ; StageAlpha §2.2: i32/str/bool/raw[N] only
    je .param_type_ok
    cmp r11b, 2
    je .param_type_ok
    cmp r11b, 3
    je .param_type_ok
    cmp r11b, 14                    ; bool
    je .param_type_ok
    jmp .err_subset
.param_type_ok:

    ; Default: consume 3 tokens (name, colon, type)
    mov rdi, 3

    ; Check for raw[N] syntax: next token should be '[' (subtype 8)
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .param_type_done
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .param_type_done
    cmp byte [r12 + 1], 8            ; '['
    jne .param_type_done

    ; Found raw[N] - parse size
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_var_type
    shl rax, 4
    lea r8, [token_array + rax]
    cmp byte [r8], 5                 ; number
    jne .err_var_type

    mov r10, [r8 + 8]                ; array size
    mov r15w, r10w                   ; store size in symbol field

    mov rax, rcx
    add rax, 6
    cmp rax, [token_count]
    jge .err_var_type
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_var_type
    cmp byte [r12 + 1], 9            ; ']'
    jne .err_var_type

    add r11b, 10                     ; flag as array type (raw[5] -> subtype 13)
    add rdi, 3                       ; consumed 3 extra tokens

.param_type_done:
    mov r8b, 5                      
    mov r9b, r11b
    xor r10, r10
    call add_symbol
    add rcx, rdi

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
    ; Inside an open mold body, lock/flux lines are layout fields, not runtime
    ; symbols (the brace guard routes only lock/flux here when braced).
    cmp qword [parse_brace_depth], 0
    je .check_var_normal
    cmp qword [mold_open], 0
    jne .check_mold_field
.check_var_normal:
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
    cmp r9b, 1                       ; StageAlpha §2.2: i32/str/bool/raw[N] only
    je .var_type_ok                  ; (extra Spec1 widths used to slip through
    cmp r9b, 2                       ; as i32-width storage — silent mismatch)
    je .var_type_ok
    cmp r9b, 3
    je .var_type_ok
    cmp r9b, 14                      ; bool
    je .var_type_ok
    jmp .err_subset
.var_type_ok:
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
    ; Identifier initializers must resolve to a plain scalar (undeclared /
    ; task / array idents used to pass the parser and die loudly at NASM;
    ; mirror the store value checks). rdi is the decl length — preserved.
    cmp byte [r12], 2
    jne .vir_not_ident
    push rdi
    push rsi                        ; keep 16-byte stack alignment across call
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; preserves rbx/rcx/rdi/r8/r12; rax/rdx out
    cmp rax, 1
    jne .vir_undecl
    cmp byte [rdx + 8], 3           ; task callee has no scalar value
    je .vir_bad
    cmp byte [rdx + 8], 11          ; lock array has no scalar value
    je .vir_bad
    cmp byte [rdx + 8], 12          ; flux array has no scalar value
    je .vir_bad
    pop rsi
    pop rdi
    jmp .vir_not_ident
.vir_undecl:
    pop rsi
    pop rdi
    jmp .err_undeclared
.vir_bad:
    pop rsi
    pop rdi
    jmp .err_expr
.vir_not_ident:
    add rdi, 2
    ; Phase 1.5c: the value must end the statement — a trailing operator
    ; would silently drop (codegen stores one value only). r10 holds the
    ; array-size pointer for add_symbol below; use r8d here, not r10d.
    mov rax, rcx
    add rax, rdi
    inc rax
    cmp rax, [token_count]
    jge .finish_var_decl
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .finish_var_decl
    mov al, [r12 + 1]
    cmp al, 6
    je .va_decl_expr
    cmp al, 7
    je .va_decl_expr
    cmp al, 16
    je .va_decl_expr
    cmp al, 17
    je .va_decl_expr
    cmp al, 18
    je .va_decl_expr
    cmp al, 2                       ; '(' : call-as-value unsupported here
    jne .finish_var_decl
.va_decl_expr:
    mov r8d, [r12 + 4]              ; operator line
    mov rax, rcx
    add rax, rdi
    shl rax, 4
    lea r12, [token_array + rax]
    cmp r8d, [r12 + 4]              ; same line as the value?
    jne .finish_var_decl
    jmp .err_expr

.finish_var_decl:
    call check_symbol_collision_scoped
    cmp rax, 1
    je .err_redeclared

    mov r8b, r11b                   
    call add_symbol
    add rcx, rdi                    
    jmp .next_token

.check_identifier:
    ; Interior idents share their line with earlier tokens (trailing operand
    ; `b` in `r = a + b`, call args, condition operands, `give` targets) and
    ; are validated by their statement checker — skip them as before. Only a
    ; line-leading ident starts a statement and is strictly validated below.
    cmp rcx, 0
    je .ci_line_start
    mov rax, rcx
    dec rax
    shl rax, 4
    lea r12, [token_array + rax]
    mov eax, [r12 + 4]              ; previous token's line
    cmp eax, [rbx + 4]              ; vs current token's line
    je .next_token                  ; same line: interior ident, legacy skip
.ci_line_start:
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .err_shape                    ; lone trailing identifier is malformed

    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape                    ; ident-led statements are assign/call/array only

    cmp byte [r12 + 1], 4
    je .valid_assign
    cmp byte [r12 + 1], 8
    je .valid_assign

    cmp byte [r12 + 1], 2
    je .valid_task_call
    jmp .err_shape                    ; e.g. `y += 1`, `y + 1`: no silent drop

.valid_task_call:
    mov r13, [rbx + 8]              
    mov r14d, [rbx + 4]             
    mov rdi, r13                     ; name ptr for find_symbol_scoped
    call find_symbol_scoped
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

    ; Phase 1.5c: array-store validation (bounds-trap soundness + shape).
    ; Layout from dest ident: +1 '[' (3,8), +2 index, +3 ']' (3,9),
    ; +4 '=' (3,4), +5 value. Anything else is the scalar '=' path.
    mov rax, rcx
    inc rax
    cmp rax, [token_count]
    jge .va_scalar_path
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .va_scalar_path
    cmp byte [r12 + 1], 8
    jne .va_scalar_path
    ; array form: dest must be a raw buffer (rdx = dest symbol, r14d = line)
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .err_index
    ; index token +2 must be an identifier or number
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .va_idx_ok
    cmp byte [r12], 5
    jne .err_shape
.va_idx_ok:
    ; +3 must be ']', +4 must be '='
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 9
    jne .err_shape
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 4
    jne .err_shape
    ; +5 value must be an identifier, number, or one-byte string
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    jne .va_not_ident
    ; identifier values must resolve to a plain scalar (not a task, which
    ; would read the code address, nor an array, which has no scalar value)
    push rbx
    push rcx
    push r12
    push rdx
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; cur_owner live during parse
    cmp rax, 1
    jne .va_val_undecl
    cmp byte [rdx + 8], 3           ; task callee
    je .va_val_bad
    cmp byte [rdx + 8], 11          ; lock array
    je .va_val_bad
    cmp byte [rdx + 8], 12          ; flux array
    je .va_val_bad
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .va_val_ok
.va_val_undecl:
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .err_undeclared
.va_val_bad:
    pop rdx
    pop r12
    pop rcx
    pop rbx
    jmp .err_expr
.va_not_ident:
    cmp byte [r12], 5
    je .va_val_ok
    cmp byte [r12], 6
    jne .err_shape
    push rbx
    push rcx
    push r12
    mov rdi, [r12 + 8]
    call get_strlen
    cmp rax, 1
    pop r12
    pop rcx
    pop rbx
    jne .err_shape
.va_val_ok:
    ; +6 must not extend the value with an arithmetic expression on the
    ; same line (codegen stores one value; the rest would silently drop)
    mov rax, rcx
    add rax, 6
    cmp rax, [token_count]
    jge .va_array_done
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .va_array_done
    mov al, [r12 + 1]
    cmp al, 6
    je .va_expr_check
    cmp al, 7
    je .va_expr_check
    cmp al, 16
    je .va_expr_check
    cmp al, 17
    je .va_expr_check
    cmp al, 18
    je .va_expr_check
    cmp al, 2                       ; '(' : call-as-value unsupported here
    je .va_expr_check
    jne .va_array_done
.va_expr_check:
    mov r10d, [r12 + 4]             ; operator line
    mov rax, rcx
    add rax, 5
    shl rax, 4
    lea r12, [token_array + rax]
    cmp r10d, [r12 + 4]             ; same line as the value?
    jne .va_array_done
    jmp .err_expr
.va_array_done:
    add rcx, 5                      ; consume dest..value
    jmp .next_token
.va_scalar_path:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .err_shape                     ; truncated `dest =` at EOF
    shl rax, 4
    lea r12, [token_array + rax]
    
    cmp byte [r12], 1
    je .check_sys_assign_parser
    ; Scalar `dest = value`: identifier values must resolve to a plain scalar
    ; (undeclared/task/array idents used to pass the parser and die loudly at
    ; NASM; mirror the array-store value check above).
    cmp byte [r12], 2
    jne .normal_assign_skip
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; preserves rbx/rcx/rdi/r8/r12; rax/rdx out
    cmp rax, 1
    jne .err_undeclared
    cmp byte [rdx + 8], 3           ; task name: valid only as call RHS
    jne .sa_val_not_task            ; `dest = fn(...)` (codegen emits the call)
    mov rax, rcx                    ; otherwise a task address read: reject
    add rax, 3
    cmp rax, [token_count]
    jge .err_expr
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_expr
    cmp byte [r12 + 1], 2           ; '('?
    jne .err_expr
    jmp .normal_assign_skip
.sa_val_not_task:
    cmp byte [rdx + 8], 11          ; lock array has no scalar value
    je .err_expr
    cmp byte [rdx + 8], 12          ; flux array has no scalar value
    je .err_expr

.normal_assign_skip:
    add rcx, 2
    jmp .next_token

.check_sys_assign_parser:
    cmp byte [r12 + 1], 6
    jne .normal_assign_skip
    ; Phase 1.5c: dest = sys(nr, a1, a2, a3) — paren/comma shape + kinds.
    ; rbx = dest token (line source). Park rcx on ')' when valid.
    mov rax, rcx
    add rax, 3
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 2           ; '('?
    jne .err_shape
    mov rax, rcx
    add rax, 4
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sa_nr_ok
    cmp byte [r12], 5
    jne .err_shape
.sa_nr_ok:
    mov rax, rcx
    add rax, 5
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 6
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sa_a1_ok
    cmp byte [r12], 5
    jne .err_shape
.sa_a1_ok:
    mov rax, rcx
    add rax, 7
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 8
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sa_a2_ok
    cmp byte [r12], 5
    je .sa_a2_ok
    cmp byte [r12], 6
    jne .err_shape
.sa_a2_ok:
    mov rax, rcx
    add rax, 9
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 10
    jne .err_shape
    mov rax, rcx
    add rax, 10
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 2
    je .sa_a3_ok
    cmp byte [r12], 5
    jne .err_shape
.sa_a3_ok:
    mov rax, rcx
    add rax, 11
    cmp rax, [token_count]
    jge .err_shape
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .err_shape
    cmp byte [r12 + 1], 3           ; ')'?
    jne .err_shape
    add rcx, 11
    jmp .next_token

.next_token:
    inc rcx                         
    jmp .parse_loop

.err_syntax:
    mov rsi, msg_err_syntax
    mov rdx, len_err_syntax
    jmp .print_syntax_err
.err_subset:
    mov rsi, msg_err_subset
    mov rdx, len_err_subset
    jmp .print_syntax_err
.err_todo:
    mov rsi, msg_err_todo
    mov rdx, len_err_todo
    jmp .print_syntax_err
.err_expr:
    mov rsi, msg_err_expr
    mov rdx, len_err_expr
    jmp .print_syntax_err
.err_shape:
    mov rsi, msg_err_shape
    mov rdx, len_err_shape
    jmp .print_syntax_err
.err_orphan:
    mov rsi, msg_err_orphan
    mov rdx, len_err_orphan
    jmp .print_syntax_err
.err_bad_condition:
    mov rsi, msg_err_cond
    mov rdx, len_err_cond
    jmp .print_syntax_err
.err_cond_rhs:
    mov rsi, msg_err_cond_rhs
    mov rdx, len_err_cond_rhs
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
    mov rdi, 2                      ; Phase 1.5b: diagnostics to stderr
    syscall
    xor rax, rax
    mov eax, dword [rbx + 4]        
    call print_num_stderr
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
    jmp .print_sem_err
.err_index:
    mov rsi, msg_err_index
    mov rdx, len_err_index
    jmp .print_sem_err
.print_sem_err:
    mov rax, 1
    mov rdi, 2                      ; Phase 1.5b: diagnostics to stderr
    syscall
    xor rax, rax
    mov eax, r14d        
    call print_num_stderr
    mov rax, 60
    mov rdi, 1
    syscall

.parse_eof_check:
    cmp qword [token_count], 0
    je .parse_success                ; empty input: downstream fails loudly
    cmp qword [parse_brace_depth], 0
    jne .err_shape                   ; unterminated '{' (e.g. unclosed mold)
    jmp .parse_success

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
