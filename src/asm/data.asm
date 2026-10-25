section .data
    usage_msg db "Usage: ./build/dharc <source_file.dhar> [--target=linux|windows]", 10, 0
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
    kw_gen db "gen", 0
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
    ; Phase 1.5: escape/skip are bootstrap-subset loop control (StageAlpha
    ; §2.2) but unimplemented; lexed as keywords so they reject loudly
    ; (todo diagnostic) instead of vanishing as identifiers
    kw_escape db "escape", 0
    kw_skip db "skip", 0
    ; Phase 1.6.2: contextual 'in' for scan (soft keyword: compared by
    ; content, never reserved, so user identifiers are unaffected)
    kw_in_soft db "in", 0
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
    kw_true db "true", 0
    kw_false db "false", 0
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
    msg_err_var_colon db "Syntax Error: Expected ':' and a type, or '=' and a value (the type is inferred), after the name on line ", 0
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
    msg_err_cond_rhs db "Syntax Error: condition compares an identifier against a number or variable only (StageAlpha 2.2) on line ", 0
    len_err_cond_rhs equ $ - msg_err_cond_rhs
    ; Phase 1.5: subset diagnostics (StageAlpha §2.2 / §4.3)
    msg_err_subset db "Syntax Error: construct not in Stage-0 bootstrap subset (StageAlpha 2.2) on line ", 0
    len_err_subset equ $ - msg_err_subset
    msg_err_todo db "Syntax Error: bootstrap-subset construct not yet implemented in Stage 0 on line ", 0
    len_err_todo equ $ - msg_err_todo
    msg_err_index db "Semantic Error: array index requires a raw buffer on line ", 0
    len_err_index equ $ - msg_err_index
    msg_err_expr db "Syntax Error: expression unsupported here; compute into a variable first on line ", 0
    len_err_expr equ $ - msg_err_expr
    msg_err_orphan db "Syntax Error: block keyword without matching opener on line ", 0
    len_err_orphan equ $ - msg_err_orphan
    msg_err_shape db "Syntax Error: malformed statement shape on line ", 0
    len_err_shape equ $ - msg_err_shape
    ; Phase 3: gen(value). One value in parentheses: a literal or the name of an i32, str or bool.
    msg_err_gen db "Syntax Error: gen takes one value in parentheses, a literal or the name of an i32, str or bool, on line ", 0
    len_err_gen equ $ - msg_err_gen
    msg_err_global_init db "Syntax Error: a name declared outside a task cannot have a starting value in Stage 0; set it inside a task, on line ", 0
    len_err_global_init equ $ - msg_err_global_init
    msg_err_gen_type db "Semantic Error: gen prints i32, str and bool values only; this name is a task, buffer or array on line ", 0
    len_err_gen_type equ $ - msg_err_gen_type
    msg_fatal_full db "Fatal Error: input exceeds compiler capacity (1MB source, 65536 tokens, 32768 symbols, 1MB strings)", 10, 0
    len_fatal_full equ $ - msg_fatal_full

    asm_data db "section .data", 10
    len_asm_data equ $ - asm_data
    asm_str_prefix db "str_"
    len_asm_str_prefix equ $ - asm_str_prefix
    ; --- Phase 1.4 (P12): global identifiers emit as dhar_<name> so user
    ;     names can never collide with NASM mnemonics, registers, _start,
    ;     generated str_N labels, or control labels (.L_*). Locals already
    ;     emit as rbp-N and are unaffected.
    asm_dhar_prefix db "dhar_"
    len_asm_dhar_prefix equ $ - asm_dhar_prefix
    asm_db_quote db " db ", 96
    len_asm_db_quote equ $ - asm_db_quote
    asm_quote_zero db 96, ", 0", 10
    len_asm_quote_zero equ $ - asm_quote_zero
    ; Phase 2 (gen fix): every string also gets  str_N_len  = its exact byte count as NASM
    ; sees it (escapes resolved, terminating NUL excluded), so gen() never writes the NUL.
    asm_str_len_a db "_len equ $ - str_"
    len_asm_str_len_a equ $ - asm_str_len_a
    asm_str_len_b db " - 1", 10
    len_asm_str_len_b equ $ - asm_str_len_b
    asm_str_len_ref db "_len"
    len_asm_str_len_ref equ $ - asm_str_len_ref
    asm_bss db 10, "section .bss", 10
    len_asm_bss equ $ - asm_bss
    asm_resq db " resq 1", 10
    len_asm_resq equ $ - asm_resq
    asm_resq_base db " resq "
    len_asm_resq_base equ $ - asm_resq_base
    asm_text db 10, "section .text", 10, "    global _start", 10, "_start:", 10, "    call dhar_core", 10, "    mov rax, 60", 10, "    xor rdi, rdi", 10, "    syscall", 10, 10
    len_asm_text equ $ - asm_text
    ; Phase 2: Windows x64 (PE32+) program header and runtime stub, used with --target=windows.
    asm_text_win:
    db "section .text", 10
    db "    global main", 10
    db "    extern GetStdHandle", 10
    db "    extern WriteFile", 10
    db "    extern ReadFile", 10
    db "    extern ExitProcess", 10
    db "main:", 10
    db "    sub rsp, 40", 10
    db "    call dhar_core", 10
    db "    mov rax, 60", 10
    db "    xor rdi, rdi", 10
    db "    call dhar_rt_syscall", 10
    db "; ---- Dhar Windows runtime (Stage 0): the portable subset of sys ----", 10
    db "; Linux numbers 0 (read), 1 (write), 60 (exit) are mapped to the Win32 calls.", 10
    db "; Any other number returns -38 (ENOSYS). Preserves everything except rax, rcx, r11.", 10
    db "dhar_rt_syscall:", 10
    db "    push rbp", 10
    db "    mov rbp, rsp", 10
    db "    push rdx", 10
    db "    push r8", 10
    db "    push r9", 10
    db "    push r10", 10
    db "    push rbx", 10
    db "    push r12", 10
    db "    push r13", 10
    db "    mov r12, rsp", 10
    db "    and rsp, -16", 10
    db "    sub rsp, 48", 10
    db "    cmp rax, 1", 10
    db "    je .rt_write", 10
    db "    cmp rax, 0", 10
    db "    je .rt_read", 10
    db "    cmp rax, 60", 10
    db "    je .rt_exit", 10
    db "    mov rax, -38", 10
    db "    jmp .rt_ret", 10
    db ".rt_write:", 10
    db "    mov r13, rsi", 10
    db "    mov rbx, rdx", 10
    db "    cmp rdi, 1", 10
    db "    je .rt_w_out", 10
    db "    cmp rdi, 2", 10
    db "    je .rt_w_err", 10
    db "    jmp .rt_badfd", 10
    db ".rt_w_out:", 10
    db "    mov ecx, -11", 10
    db "    jmp .rt_w_go", 10
    db ".rt_w_err:", 10
    db "    mov ecx, -12", 10
    db ".rt_w_go:", 10
    db "    call GetStdHandle", 10
    db "    mov rcx, rax", 10
    db "    mov rdx, r13", 10
    db "    mov r8, rbx", 10
    db "    lea r9, [rsp+40]", 10
    db "    mov qword [rsp+32], 0", 10
    db "    call WriteFile", 10
    db "    test eax, eax", 10
    db "    jz .rt_io_err", 10
    db "    mov eax, dword [rsp+40]", 10
    db "    jmp .rt_ret", 10
    db ".rt_read:", 10
    db "    mov r13, rsi", 10
    db "    mov rbx, rdx", 10
    db "    test rdi, rdi", 10
    db "    jnz .rt_badfd", 10
    db "    mov ecx, -10", 10
    db "    call GetStdHandle", 10
    db "    mov rcx, rax", 10
    db "    mov rdx, r13", 10
    db "    mov r8, rbx", 10
    db "    lea r9, [rsp+40]", 10
    db "    mov qword [rsp+32], 0", 10
    db "    call ReadFile", 10
    db "    test eax, eax", 10
    db "    jz .rt_io_err", 10
    db "    mov eax, dword [rsp+40]", 10
    db "    jmp .rt_ret", 10
    db ".rt_badfd:", 10
    db "    mov rax, -9", 10
    db "    jmp .rt_ret", 10
    db ".rt_io_err:", 10
    db "    mov rax, -5", 10
    db "    jmp .rt_ret", 10
    db ".rt_exit:", 10
    db "    mov ecx, edi", 10
    db "    call ExitProcess", 10
    db ".rt_ret:", 10
    db "    mov rsp, r12", 10
    db "    pop r13", 10
    db "    pop r12", 10
    db "    pop rbx", 10
    db "    pop r10", 10
    db "    pop r9", 10
    db "    pop r8", 10
    db "    pop rdx", 10
    db "    pop rbp", 10
    db "    ret", 10
    db "", 10
    len_asm_text_win equ $ - asm_text_win
    asm_syscall_win db "    call dhar_rt_syscall", 10
    len_asm_syscall_win equ $ - asm_syscall_win
    msg_err_target db "Fatal Error: unsupported target. Stage 0 implements --target=linux and --target=windows only (arm64, riscv64 and wasi are planned for the Stage 1 backends)", 10, 0
    len_err_target equ $ - msg_err_target
    
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
    asm_minus db "-"
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
    ; --- Phase 1.2 (P2/P11): raw[N] is N bytes (Spec1 §14.4) with byte-wide
    ;     peek/poke primitives, so buf[i]=v stores ONE byte at buf+i.
    ;     (The qword/stride-8 form above is retired; kept for reference.)
    asm_mov1_byte db "    mov byte ["
    len_asm_mov1_byte equ $ - asm_mov1_byte
    asm_array_store_byte db " + rax], cl", 10
    len_asm_array_store_byte equ $ - asm_array_store_byte
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

    ; --- Phase 3: gen(value) for i32, str and bool values -------------------------------------------
    ; gen("text") still writes the literal directly. gen(5), gen(true), gen(name) load the value into
    ; rax and call a small routine that is added to the end of the program ONLY if the program uses it
    ; (so programs that do not print values do not change size). Each routine keeps every register
    ; except rax, writes to standard output (file 1) and uses the target's own sys call text, so it is
    ; the same on Linux and Windows. No newline is added; write "\n" for one.
    asm_call_gen_i32 db "    call dhar$gen$i32", 10
    len_asm_call_gen_i32 equ $ - asm_call_gen_i32
    asm_call_gen_str db "    call dhar$gen$str", 10
    len_asm_call_gen_str equ $ - asm_call_gen_str
    asm_call_gen_bool db "    call dhar$gen$bool", 10
    len_asm_call_gen_bool equ $ - asm_call_gen_bool

    ; i32: the value in rax, printed as a signed decimal number
    gen_i32_a:
    db 10
    db "; ---- gen: print a signed number (rax) ----", 10
    db "dhar$gen$i32:", 10
    db "    push rbx", 10
    db "    push rcx", 10
    db "    push rdx", 10
    db "    push rsi", 10
    db "    push rdi", 10
    db "    push r8", 10
    db "    sub rsp, 48", 10
    db "    lea rsi, [rsp + 48]", 10
    db "    mov r8, rax", 10
    db "    mov rbx, rax", 10
    db "    test rbx, rbx", 10
    db "    jns .pos", 10
    db "    neg rbx", 10
    db ".pos:", 10
    db "    mov rax, rbx", 10
    db "    mov rcx, 10", 10
    db ".digit:", 10
    db "    xor edx, edx", 10
    db "    div rcx", 10
    db "    add dl, 48", 10
    db "    dec rsi", 10
    db "    mov [rsi], dl", 10
    db "    test rax, rax", 10
    db "    jnz .digit", 10
    db "    test r8, r8", 10
    db "    jns .unsigned", 10
    db "    dec rsi", 10
    db "    mov byte [rsi], 45", 10
    db ".unsigned:", 10
    db "    lea rdx, [rsp + 48]", 10
    db "    sub rdx, rsi", 10
    db "    mov rax, 1", 10
    db "    mov rdi, 1", 10
    len_gen_i32_a equ $ - gen_i32_a
    gen_i32_b:
    db "    add rsp, 48", 10
    db "    pop r8", 10
    db "    pop rdi", 10
    db "    pop rsi", 10
    db "    pop rdx", 10
    db "    pop rcx", 10
    db "    pop rbx", 10
    db "    ret", 10
    len_gen_i32_b equ $ - gen_i32_b

    ; str: rax holds the address of the text, which ends at a zero byte (a str name holds that address)
    gen_str_a:
    db 10
    db "; ---- gen: print a str (rax = address of zero-ended text) ----", 10
    db "dhar$gen$str:", 10
    db "    push rcx", 10
    db "    push rdx", 10
    db "    push rsi", 10
    db "    push rdi", 10
    db "    mov rsi, rax", 10
    db "    xor edx, edx", 10
    db "    test rsi, rsi", 10
    db "    jz .done", 10
    db ".count:", 10
    db "    cmp byte [rsi + rdx], 0", 10
    db "    je .write", 10
    db "    inc rdx", 10
    db "    jmp .count", 10
    db ".write:", 10
    db "    test rdx, rdx", 10
    db "    jz .done", 10
    db "    mov rax, 1", 10
    db "    mov rdi, 1", 10
    len_gen_str_a equ $ - gen_str_a
    gen_str_b:
    db ".done:", 10
    db "    pop rdi", 10
    db "    pop rsi", 10
    db "    pop rdx", 10
    db "    pop rcx", 10
    db "    ret", 10
    len_gen_str_b equ $ - gen_str_b

    ; bool: rax is zero for false, anything else for true
    gen_bool_a:
    db 10
    db "; ---- gen: print a bool (rax) ----", 10
    db "dhar$gen$bool:", 10
    db "    push rcx", 10
    db "    push rdx", 10
    db "    push rsi", 10
    db "    push rdi", 10
    db "    mov rsi, dhar$gen$false", 10
    db "    mov edx, 5", 10
    db "    test rax, rax", 10
    db "    jz .write", 10
    db "    mov rsi, dhar$gen$true", 10
    db "    mov edx, 4", 10
    db ".write:", 10
    db "    mov rax, 1", 10
    db "    mov rdi, 1", 10
    len_gen_bool_a equ $ - gen_bool_a
    gen_bool_b:
    db "    pop rdi", 10
    db "    pop rsi", 10
    db "    pop rdx", 10
    db "    pop rcx", 10
    db "    ret", 10
    db "section .data", 10
    db "dhar$gen$true db ", 96, "true", 96, 10
    db "dhar$gen$false db ", 96, "false", 96, 10
    len_gen_bool_b equ $ - gen_bool_b

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

    ; --- Phase 1.5a: bounds-trap emission strings (Spec1 §14.4) ---
    asm_cmp_rax_zero db "    cmp rax, 0", 10
    len_asm_cmp_rax_zero equ $ - asm_cmp_rax_zero
    asm_jl_trap db "    jl .L_TRAP_"
    len_asm_jl_trap equ $ - asm_jl_trap
    asm_jge_trap db "    jge .L_TRAP_"
    len_asm_jge_trap equ $ - asm_jge_trap
    asm_jmp_trap_ok db "    jmp .L_TRAP_OK_"
    len_asm_jmp_trap_ok equ $ - asm_jmp_trap_ok
    asm_trap_lbl db ".L_TRAP_"
    len_asm_trap_lbl equ $ - asm_trap_lbl
    asm_trap_ok_lbl db ".L_TRAP_OK_"
    len_asm_trap_ok_lbl equ $ - asm_trap_ok_lbl
    ; $ is NASM-legal but not a Dhar identifier char: user code can never
    ; collide with this shared trap-message label (even with dhar_ mangling)
    asm_trap_msg_ref db "dhar$trap$msg"
    len_asm_trap_msg_ref equ $ - asm_trap_msg_ref
    asm_trap_msg_decl db "dhar$trap$msg db ", 96, "Dhar: index out of bounds", 96, ", 10, 0", 10
    len_asm_trap_msg_decl equ $ - asm_trap_msg_decl
    asm_mov_rax_one db "    mov rax, 1", 10
    len_asm_mov_rax_one equ $ - asm_mov_rax_one
    asm_mov_rdi_two db "    mov rdi, 2", 10
    len_asm_mov_rdi_two equ $ - asm_mov_rdi_two
    asm_mov_rdx_trap_len db "    mov rdx, 26", 10
    len_asm_mov_rdx_trap_len equ $ - asm_mov_rdx_trap_len
    asm_mov_rax_60 db "    mov rax, 60", 10
    len_asm_mov_rax_60 equ $ - asm_mov_rax_60
    asm_mov_rdi_one db "    mov rdi, 1", 10
    len_asm_mov_rdi_one equ $ - asm_mov_rdi_one
    asm_mov_rsi_trap db "    mov rsi, dhar$trap$msg", 10
    len_asm_mov_rsi_trap equ $ - asm_mov_rsi_trap
    ; --- Phase 1.6.2: scan-loop emission pieces (counter lives in frame) ---
    asm_mov_rbp_open db "    mov qword [rbp-"
    len_asm_mov_rbp_open equ $ - asm_mov_rbp_open
    asm_close_zero db "], 0", 10
    len_asm_close_zero equ $ - asm_close_zero
    asm_cmp_rbp_open db "    cmp qword [rbp-"
    len_asm_cmp_rbp_open equ $ - asm_cmp_rbp_open
    asm_mov_rax_rbp db "    mov rax, qword [rbp-"
    len_asm_mov_rax_rbp equ $ - asm_mov_rax_rbp
    asm_inc_rbp db "    inc qword [rbp-"
    len_asm_inc_rbp equ $ - asm_inc_rbp

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
    cur_syscall_ptr resq 1          ; Phase 2: per-target emission choices, set in run_codegen
    cur_syscall_len resq 1
    cur_text_ptr resq 1
    cur_text_len resq 1
    target_os_flag resq 1           ; 0 = Linux, 1 = Windows PE, 2 = WASI
    last_token_type resb 1          ; V0.3.0 unary-minus detection
    bool_lit_flag resb 1            ; Phase 3: the word being stored is true/false (a bool literal)
    gen_need resb 1                 ; Phase 3: bit 0 i32, bit 1 str, bit 2 bool helper needed at the end
    gen_cur_type resb 1             ; Phase 3: type code of the value gen() is printing (1 i32, 2 str, 14 bool)

    ; --- V0.3.0 Stack-frame machinery ---
    frame_offsets resq 256          ; per-task frame sizes (bytes), 1-indexed
    local_counts resq 256           ; per-task local variable counts
    task_frame_count resq 1
    scan_in_task resq 1
    scan_task_indent resd 1
    scan_task_id resq 1
    scan_frame_off resq 1
    cg_cur_task resq 1              ; codegen current task ordinal
    cg_scan_idx resq 1              ; Phase 1.6.2: scans emitted in current task
    scan_ctr_total resq 256         ; Phase 1.6.2: counter slots per task
    ecs_callee_tok resq 1           ; V0.3.0 callee token ptr during call emission
    cg_ret_label resq 1             ; label id of current task's epilogue
    in_task_flag resb 1
    mold_owner resq 1                ; V0.3.1: owner for mold fields
    mold_depth resq 1               ; track mold nesting depth
    parse_task_counter resq 1       ; V0.3.0 scoping: task ordinal at parse time
    cur_owner resq 1                ; V0.3.0 scoping: current declaration owner
    ; --- Phase 1.6: parse-time block stack (orphan shift/fallback/escape
    ;     detection) + brace depth (mold bodies gate control keywords)
    parse_cf_indent resw 256        ; indent per depth (words)
    parse_cf_kind resb 256          ; kind per depth (1 when,2 span,3 consumed,
                                    ; 4 task,5 shift-link,6 cycle,7 scan)
    parse_cf_depth resq 1           ; current depth
    parse_brace_depth resq 1        ; { } nesting level
    ; --- mold layout registry (StageAlpha §2.2, layout only): separate type
    ;     namespace; the bridge records (name, field count, byte size) and
    ;     emits no code. Per-field offsets are Beta's job (it re-parses).
    mold_names resq 64            ; mold type name string ptrs
    mold_sizes resq 64            ; layout size in bytes
    mold_fcounts resq 64          ; field counts
    mold_count resq 1             ; declared molds (cap 64, else fatal_full)
    mold_open resq 1              ; 1-based open mold while parsing fields
    mold_cur_off resq 1           ; running layout offset of the open mold

