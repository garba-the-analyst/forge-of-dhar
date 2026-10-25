; codegen.asm - code generation via template emitter (StageAlpha 3)
section .text

run_codegen:
    ; Phase 2: choose the per-target program header and the way `sys` is emitted
    mov qword [cur_syscall_ptr], asm_syscall
    mov qword [cur_syscall_len], len_asm_syscall
    mov qword [cur_text_ptr], asm_text
    mov qword [cur_text_len], len_asm_text
    cmp qword [target_os_flag], 1
    jne .target_chosen
    mov qword [cur_syscall_ptr], asm_syscall_win
    mov qword [cur_syscall_len], len_asm_syscall_win
    mov qword [cur_text_ptr], asm_text_win
    mov qword [cur_text_len], len_asm_text_win
.target_chosen:
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

    ; gen fix: str_N_len equ $ - str_N - 1
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, rcx
    call write_rax_to_file
    mov rsi, asm_str_len_a
    mov rdx, len_asm_str_len_a
    call write_to_file
    mov rax, rcx
    call write_rax_to_file
    mov rsi, asm_str_len_b
    mov rdx, len_asm_str_len_b
    call write_to_file

.data_skip:
    inc rcx
    jmp .data_loop
.data_done:

    ; Phase 1.5a: shared bounds-trap message (referenced by every trap site)
    mov rsi, asm_trap_msg_decl
    mov rdx, len_asm_trap_msg_decl
    call write_to_file

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
    cmp dword [rbx + 20], 0         ; V0.4.1: owner=0 -> global, owner>0 -> task-local
    jne .bss_skip
    cmp dword [rbx + 16], 0         ; V0.4.1: stack offset=0 -> global, !=0 -> local
    jne .bss_skip

    mov rdi, [rbx]                      ; Phase 1.4: dhar_ prefix (NASM-safe)
    call emit_mangled_name

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

    mov rsi, [cur_text_ptr]
    mov rdx, [cur_text_len]
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
    je .fb_kind_check
    ; Phase 1.6: shift interception. A shift token chains onto the head
    ; frame at its own indent (parser already validated the chain).
    cmp byte [rbx + 1], 12          ; shift?
    jne .normal_close
    cmp dx, [r12 + 8]               ; head at this indent?
    jne .normal_close               ; deeper head closes normally
    cmp r13, 1
    je .shift_chain
    cmp r13, 5
    je .shift_chain
    jmp .normal_close               ; orphan shape: parser-gated, defensive
.fb_kind_check:
    cmp r13, 1
    je .fb_consume
    cmp r13, 5                      ; Phase 1.6: fallback also closes shifts
    jne .normal_close
.fb_consume:
    cmp dx, [r12 + 8]               ; Phase 1.1 (P7): fallback binds only to the frame
    jne .normal_close               ; at its own indent; an outer fallback must not
                                    ; be consumed by an inner when (which dropped the
                                    ; outer jmp .L_END_ and fell into both branches)
    ; Phase 1.6: the then-block exits past the ULTIMATE chain end, not the
    ; top link's own end (plain when/fallback: chain == self, same thing).
    ; The fallback LABEL itself is always the top frame's.
    mov rax, [r12 + 24]
    test rax, rax
    jz .fb_emit_both                ; rdi already the top id
    push rdi                        ; stash top id
    mov rdi, rax
    call emit_jmp_end               ; jmp .L_END_chain
    pop rdi                         ; top id
    call emit_fallback_label        ; .L_FALLBACK_top:
    mov qword [r12 + 16], 3
    add rcx, 1
    jmp .text_skip
.fb_emit_both:
    call emit_jmp_end
    call emit_fallback_label
    mov qword [r12 + 16], 3
    add rcx, 1
    jmp .text_skip

.shift_chain:
    ; Phase 1.6: chain a shift link onto head frame P.
    ; r12 = P, rdi = P.id, dx = cur indent, rbx = shift token, rcx = its index.
    ; U = P.chain (+24; 0 on pre-chain frames -> use P defensively).
    ; Emits jmp .L_END_U + .L_FALLBACK_P:, pops P, pushes the new kind-5
    ; link (chain U), emits the shift condition (fallback variant).
    ; NOTE: r15 is the output fd — never use it as scratch here. U lives
    ; in r10 (saved/restored) and P.id rides the stack across the calls.
    push r10
    mov r10, [r12 + 24]             ; U = ultimate chain end
    test r10, r10
    jnz .sc_have_u
    mov r10, rdi
.sc_have_u:
    push rdi                        ; stash P.id
    mov rdi, r10
    call emit_jmp_end               ; jmp .L_END_U
    pop rdi                         ; P.id
    call emit_fallback_label        ; .L_FALLBACK_P:
    dec qword [cf_sp]               ; pop P (its END arrives at chain end)
    mov rax, [label_id_counter]
    inc qword [label_id_counter]
    mov r14, [cf_sp]
    cmp r14, 2048
    jae fatal_full
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov [r11], rax
    mov dx, [rbx + 2]               ; RELOAD: emission calls clobber rdx
    mov [r11 + 8], dx
    mov qword [r11 + 16], 5
    mov [r11 + 24], r10
    inc qword [cf_sp]
    mov rdi, rax                    ; new id for the exit jump
    push rdi
    call .emit_cond_cmp              ; mov + cmp (rcx preserved)
    pop rdi
    mov bl, 1                       ; shift exits to fallback labels
    call .emit_cond_jump
    pop r10                         ; restore caller r10 (r15 fd never touched)
    add rcx, 4
    jmp .text_skip

.normal_close:
    cmp r13, 4                      
    je .task_close
    cmp r13, 2
    je .loop_close
    cmp r13, 6                      ; Phase 1.6: cycle loops back (1.6.2)
    je .loop_close
    cmp r13, 7                      ; Phase 1.6: scan loops back (1.6.2)
    je .loop_close
    cmp r13, 1
    je .nc_when
    cmp r13, 5                      ; Phase 1.6: dedent-closed shift link
    je .nc_shift
    jmp .nc_end_common              ; kind 3 (consumed): end (+chain) below
.loop_close:
    ; Phase 1.6.2: scan links (kind 7) keep their counter in the frame
    ; slot recorded at +24; increment it before looping back.
    cmp r13, 7
    jne .loop_no_inc
    mov rsi, asm_inc_rbp
    mov rdx, len_asm_inc_rbp
    call write_to_file
    mov rax, [r12 + 24]
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.loop_no_inc:
    call emit_jmp_start
    jmp .nc_end_common
.nc_when:
    call emit_fallback_label        ; dummy (no else branch)
    jmp .nc_end_common
.nc_shift:
    call emit_fallback_label        ; dummy F_new (unreferenced)
.nc_end_common:
    call emit_end_label             ; END_self (rdi = self id, still live)
    ; chain end: only shift links (kind 5) and consumed frames from them
    ; (kind 3) consult +24 as a chain id. Whens/spans/loops keep their own
    ; id there (scan keeps its counter slot) and end once.
    cmp r13, 5
    je .nc_chain_check
    cmp r13, 3
    jne .nc_chain_done
.nc_chain_check:
    mov rax, [r12 + 24]
    test rax, rax
    jz .nc_chain_done
    cmp rax, rdi
    je .nc_chain_done
    push rdi
    mov rdi, rax
    call emit_end_label             ; END_chain
    pop rdi
.nc_chain_done:
    jmp .do_cleanup
.task_close:
    mov byte [in_task_flag], 0
    call emit_task_epilogue
    jmp .do_cleanup
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
    cmp byte [rbx + 1], 25          ; gen
    je .handle_gen
    cmp byte [rbx + 1], 13          ; Phase 1.6.2: scan
    je .handle_scan
    cmp byte [rbx + 1], 14          ; Phase 1.6.2: cycle
    je .handle_cycle
    cmp byte [rbx + 1], 26          ; Phase 1.6.2: escape
    je .handle_escape
    cmp byte [rbx + 1], 27          ; Phase 1.6.2: skip
    je .handle_escape               ; (same nearest-loop scan)
    jmp .text_skip

.handle_cycle:
    ; Phase 1.6.2: cycle ':' — infinite loop (parser: shape + body checked).
    ; Exits only via escape (which jumps the frame's END label).
    mov rdi, [label_id_counter]
    inc qword [label_id_counter]
    mov r14, [cf_sp]
    cmp r14, 2048
    jae fatal_full
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov [r11], rdi
    mov dx, [rbx + 2]
    mov [r11 + 8], dx
    mov qword [r11 + 16], 6
    mov [r11 + 24], rdi             ; chain end starts as self
    inc qword [cf_sp]
    push rdi
    call emit_start_label           ; .L_START_id:
    pop rdi
    add rcx, 1                      ; consume 'cycle' (':' skipped by loop)
    jmp .text_skip
.handle_scan:
    ; Phase 1.6.2: scan x in buf ':' — x takes each byte value in order.
    ; Tokens from rcx: 0 scan, 1 x, 2 in, 3 buf, 4 ':'. Parser validated.
    ; Counter slot OFF = frame_bytes - 8*(j+1), j = this task's scan index
    ; (slots sit below the regulars; frame covers them by construction).
    mov rax, [cg_scan_idx]
    inc qword [cg_scan_idx]
    mov r10, rax                    ; j (survives: untouched below)
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; rax?/rdx = buf sym (parser guarantees)
    mov r13, 8                      ; default N = 8 (bare raw)
    xor r9b, r9b                    ; 0 = global addr, 1 = local lea
    cmp rax, 1
    jne .scan_have_n
    mov rsi, [rdx + 24]
    test rsi, rsi
    jz .scan_n_set
    mov rdi, rsi
    call parse_uint                 ; rax = N (preserves rdx)
    mov r13, rax
.scan_n_set:
    test byte [rdx + 9], 0x80
    jz .scan_have_n
    mov r9b, 1
    mov r8, [rdx + 16]              ; buf frame offset for lea
.scan_have_n:
    ; OFF = 8 * (slot count + j + 1): counters sit above the regulars.
    ; local_counts counts slots (arrays take ceil(N/8)) since Phase 1.6.2.
    mov rax, [cg_cur_task]
    mov rdx, [local_counts + rax*8 - 8]
    add rdx, r10
    inc rdx
    shl rdx, 3
    mov r10, rdx                    ; OFF kept in r10
    ; push the scan frame (fresh id, cur indent, kind 7, +24 = OFF)
    mov rdi, [label_id_counter]
    inc qword [label_id_counter]
    mov r14, [cf_sp]
    cmp r14, 2048
    jae fatal_full
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov [r11], rdi
    mov dx, [rbx + 2]
    mov [r11 + 8], dx
    mov qword [r11 + 16], 7
    mov [r11 + 24], r10
    inc qword [cf_sp]
    push rdi                        ; id saved for START/END labels
    ; counter init: mov qword [rbp-OFF], 0
    mov rsi, asm_mov_rbp_open
    mov rdx, len_asm_mov_rbp_open
    call write_to_file
    mov rax, r10
    call write_rax_to_file
    mov rsi, asm_close_zero
    mov rdx, len_asm_close_zero
    call write_to_file
    ; .L_START_id:
    mov rdi, [rsp]
    call emit_start_label
    ; cmp qword [rbp-OFF], N
    mov rsi, asm_cmp_rbp_open
    mov rdx, len_asm_cmp_rbp_open
    call write_to_file
    mov rax, r10
    call write_rax_to_file
    mov rsi, asm_mov2                ; "], "
    mov rdx, len_asm_mov2
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    ; jge .L_END_id
    mov rdi, [rsp]
    mov rsi, asm_jge_l_end
    mov rdx, len_asm_jge_l_end
    call write_to_file
    mov rax, rdi
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    ; x = peek(buf, counter): mov rax, [rbp-OFF]
    mov rsi, asm_mov_rax_rbp
    mov rdx, len_asm_mov_rax_rbp
    call write_to_file
    mov rax, r10
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    ; rsi = buf address
    cmp r9b, 1
    je .scan_buf_local
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call emit_mangled_name           ; global addr (mangled)
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .scan_peek_emit
.scan_buf_local:
    mov rsi, asm_lea_rsi_open
    mov rdx, len_asm_lea_rsi_open
    call write_to_file
    mov rsi, asm_rbp_prefix
    mov rdx, len_asm_rbp_prefix
    call write_to_file
    mov eax, r8d                     ; low 32 bits only: the upper half of r8 is not guaranteed zero
                                     ; (it used to print rbp-4294967336 for rbp-40; nasm truncated it back)
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.scan_peek_emit:
    ; xor rcx,rcx; mov cl,[rsi+rax]; mov [x],rcx (peek strings)
    mov rsi, asm_peek_3
    mov rdx, len_asm_peek_3
    call write_to_file
    mov rax, rcx
    inc rax                          ; x token at rcx+1
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call emit_named_operand          ; x slot (slotted by precompute)
    mov rsi, asm_peek_4
    mov rdx, len_asm_peek_4
    call write_to_file
    pop rdi                          ; balance id save (END label at close)
    add rcx, 4
    jmp .text_skip
.handle_shift:
    ; Defensive only: every valid shift is intercepted in .check_cf_close
    ; (parser validates the chain, so this is unreachable). Skip one token.
    jmp .text_skip
.handle_escape:
    ; Phase 1.6.2: escape/skip jump to the nearest enclosing loop's END /
    ; START (kinds 2/6/7 strictly above this line). Parser validated context.
    mov dx, [rbx + 2]               ; current indent
    mov r14, [cf_sp]
    cmp byte [rbx + 1], 26          ; escape (break) vs skip (continue)?
    je .esc_is_escape
.sk_loop:
    test r14, r14
    jz .esc_done                    ; unreachable: parser-gated
    dec r14
    mov rax, r14
    shl rax, 5
    lea r11, [cf_stack + rax]
    movzx eax, word [r11 + 8]
    cmp ax, dx
    jae .sk_loop                    ; loop must strictly contain this line
    mov r13, [r11 + 16]
    cmp r13, 2
    je .sk_fire
    cmp r13, 6
    je .sk_fire
    cmp r13, 7
    jne .sk_loop
.sk_fire:
    mov rdi, [r11]
    call emit_jmp_start
    jmp .esc_done
.esc_is_escape:
    test r14, r14
    jz .esc_done
    dec r14
    mov rax, r14
    shl rax, 5
    lea r11, [cf_stack + rax]
    movzx eax, word [r11 + 8]
    cmp ax, dx
    jae .esc_is_escape
    mov r13, [r11 + 16]
    cmp r13, 2
    je .esc_fire
    cmp r13, 6
    je .esc_fire
    cmp r13, 7
    jne .esc_is_escape
.esc_fire:
    mov rdi, [r11]
    call emit_jmp_end
.esc_done:
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
    ; Phase 1.5a: bounds-check the index in rax against buf raw[N]
    mov rdi, [r12 + 8]
    call emit_bounds_trap
    mov rdi, [r12 + 8]
    mov r13, rdi
    call find_symbol_scoped
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

    ; Phase 1.5a: bounds-check the index in rax against buf raw[N]
    mov rdi, [r12 + 8]
    call emit_bounds_trap

    ; V0.3.0: local buffers are frame-resident -> lea rsi, [rbp-N]
    mov rdi, [r12 + 8]
    mov r13, rdi
    call find_symbol_scoped
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
    ; Phase 3: inferred form `lock|flux NAME = VALUE`: the '=' is the third token, so the base is 1
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .var_cg_typed
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 3
    jne .var_cg_typed
    cmp byte [r12 + 1], 4
    jne .var_cg_typed
    mov r14, 1
    jmp .var_cg_check_eq
.var_cg_typed:
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
 
    cmp byte [r13], 2               ; Phase 1.2b: identifier initializer
    je .cg_inline_ident             ; (flux x: i32 = y) needs load-then-store;
                                    ; the literal path below would emit the bare
                                    ; name as an immediate (wrong value / NASM error)
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
.cg_inline_ident:
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
    mov rdi, [r8 + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
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
    mov rdi, [r12 + 8]                  ; Phase 1.4: task label dhar_<name>
    call emit_mangled_name
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file

    ; --- V0.3.0 prologue ---
    inc qword [cg_cur_task]
    mov rax, [cg_cur_task]
    mov [cg_ret_label], rax
    mov [cur_owner], rax              ; sync cur_owner with cg_cur_task for scoped lookups
    mov qword [cg_scan_idx], 0        ; Phase 1.6.2: per-task scan counter
    mov r10, rax                      ; save task ordinal
    mov byte [in_task_flag], 1
    push rcx                        ; SAVE token index (rcx is the parse cursor!)
    mov rsi, asm_prologue
    mov rdx, len_asm_prologue
    call write_to_file
    mov rax, [frame_offsets + r10*8 - 8]  ; frame size for THIS ordinal
    test rax, rax
    jnz .prologue_got_frame
    mov rax, [local_counts + r10*8 - 8]   ; fallback: slot count * 8
    add rax, [scan_ctr_total + r10*8 - 8] ; Phase 1.6.2: + scan counters
    shl rax, 3
    add rax, 15
    and rax, -16
    mov [frame_offsets + r10*8 - 8], rax  ; cache it
.prologue_got_frame:
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
    call find_symbol_scoped         ; -> rdx = symbol
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
    cmp r14, 2048                   ; Phase 1.5b: cf_stack holds 2048 frames
    jae fatal_full
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
    ; Phase 1.6: frame push + span-start here; condition emission shared
    ; via emit_cond_cmp / emit_cond_jump (rcx = keyword index throughout).
    mov rdi, [label_id_counter]
    inc qword [label_id_counter]

    mov r14, [cf_sp]
    cmp r14, 2048                   ; Phase 1.5b: cf_stack holds 2048 frames
    jae fatal_full
    shl r14, 5
    lea r11, [cf_stack + r14]
    mov [r11], rdi
    mov dx, [rbx + 2]
    mov [r11 + 8], dx
    mov [r11 + 24], rdi             ; Phase 1.6: chain end starts as self

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

    call .emit_cond_cmp               ; mov rax,[ident] + cmp (preserves rcx)
    cmp byte [rbx + 1], 4           ; when -> fallback-label variant
    je .cf_use_fb
    xor bl, bl                      ; span -> end-label variant
    jmp .cf_emit_jump
.cf_use_fb:
    mov bl, 1
.cf_emit_jump:
    call .emit_cond_jump              ; (rcx, rdi = id, bl = variant)
    add rcx, 4
    jmp .text_skip

; ------------------------------------------------------------------------------
; Phase 1.6 condition emission (shared by when/span/shift):
;   emit_cond_cmp: IN rcx = keyword index of [kw, ident, op, value].
;     Emits `mov rax, qword [ident]` + `cmp rax, <value|mem>`.
;   emit_cond_jump: IN rcx = same, rdi = label id, bl = 1 -> .L_FALLBACK_<id>
;     variant (when/shift), bl = 0 -> .L_END_<id> variant (span loops).
;     Emits the operator-selective conditional jump (inverse of the operator).
;   Both preserve rbx, rcx, rdi and all of r8-r15 except rax/rsi/rdx.
; ------------------------------------------------------------------------------
.emit_cond_cmp:
    push rax
    push rbx
    push rcx
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    mov rax, rcx
    inc rax
    shl rax, 4
    lea r12, [token_array + rax]
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r13, [token_array + rax]
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    cmp byte [r13], 2
    je .ecc_rhs_mem
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
    jmp .ecc_done
.ecc_rhs_mem:
    mov rsi, asm_cmp_rax_mem
    mov rdx, len_asm_cmp_rax_mem
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.ecc_done:
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret
.emit_cond_jump:
    push rax
    push rbx
    push rcx
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    mov r14b, bl                    ; stash variant (bl reused below? no—keep)
    mov rax, rcx
    add rax, 2
    shl rax, 4
    lea r12, [token_array + rax]
    movzx r13d, byte [r12 + 1]      ; operator subtype
    cmp r13b, 15                    ; '!=' -> je
    je .ecj_ne
    cmp r13b, 11                    ; '<' -> jge
    je .ecj_lt
    cmp r13b, 12                    ; '>' -> jle
    je .ecj_gt
    cmp r13b, 13                    ; '<=' -> jg
    je .ecj_le
    cmp r13b, 14                    ; '>=' -> jl
    je .ecj_ge
    mov r8, asm_jne_l_end           ; default '==' -> jne
    mov r9, len_asm_jne_l_end
    mov r10, asm_jne_l_fallback
    mov r11, len_asm_jne_l_fallback
    jmp .ecj_pick
.ecj_ne:
    mov r8, asm_je_l_end
    mov r9, len_asm_je_l_end
    mov r10, asm_je_l_fallback
    mov r11, len_asm_je_l_fallback
    jmp .ecj_pick
.ecj_lt:
    mov r8, asm_jge_l_end
    mov r9, len_asm_jge_l_end
    mov r10, asm_jge_l_fallback
    mov r11, len_asm_jge_l_fallback
    jmp .ecj_pick
.ecj_gt:
    mov r8, asm_jle_l_end
    mov r9, len_asm_jle_l_end
    mov r10, asm_jle_l_fallback
    mov r11, len_asm_jle_l_fallback
    jmp .ecj_pick
.ecj_le:
    mov r8, asm_jg_l_end
    mov r9, len_asm_jg_l_end
    mov r10, asm_jg_l_fallback
    mov r11, len_asm_jg_l_fallback
    jmp .ecj_pick
.ecj_ge:
    mov r8, asm_jl_l_end
    mov r9, len_asm_jl_l_end
    mov r10, asm_jl_l_fallback
    mov r11, len_asm_jl_l_fallback
.ecj_pick:
    cmp r14b, 1
    je .ecj_fb
    mov rsi, r8
    mov rdx, r9
    jmp .ecj_write
.ecj_fb:
    mov rsi, r10
    mov rdx, r11
.ecj_write:
    call write_to_file
    mov rax, rdi                    ; label id (preserved by our frame)
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

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
    mov rdi, r13
    call find_symbol_scoped
    pop r13
    cmp rax, 1
    jne .sys_rdi_normal
    mov al, [rdx + 9]               ; Phase 1.3: mask locality bit — raw is raw
    and al, 0x7F                    ; (local raw is 0x83, global raw is 3);
    cmp al, 3                       ; unmasked check passed locals to the
    jne .sys_rdi_normal             ; value path (content as pointer -> silence)
    test byte [rdx + 9], 0x80          
    jz .sys_rdi_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
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
    jmp .sys_rsi
.sys_rdi_addr:                      ; Phase 1.4: global raw address, mangled
    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_mangled_name
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
    mov rdi, r13
    call find_symbol_scoped
    pop r13
    cmp rax, 1
    jne .sys_rsi_normal
    mov al, [rdx + 9]               ; Phase 1.3: mask locality bit (see .sys_rdi)
    and al, 0x7F
    cmp al, 3
    jne .sys_rsi_normal
    test byte [rdx + 9], 0x80          
    jz .sys_rsi_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
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
.sys_rsi_addr:                      ; Phase 1.4: global raw address, mangled
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_mangled_name
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
    mov rdi, r13
    call find_symbol_scoped
    pop r13
    cmp rax, 1
    jne .sys_rdx_normal
    mov al, [rdx + 9]               ; Phase 1.3: mask locality bit (see .sys_rdi)
    and al, 0x7F
    cmp al, 3
    jne .sys_rdx_normal
    test byte [rdx + 9], 0x80          
    jz .sys_rdx_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
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
    jmp .sys_emit
.sys_rdx_addr:                      ; Phase 1.4: global raw address, mangled
    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    call write_to_file
    mov rdi, [r13 + 8]
    call emit_mangled_name
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_emit

.sys_emit:
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
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
    je .give_check_binop
    cmp byte [r12], 5
    je .give_check_binop
    cmp byte [r12], 6
    je .give_str
    cmp byte [r12], 3               ; '-' N : negative literal
    jne .give_bare_emit
    cmp byte [r12 + 1], 7
    jne .give_bare_emit
    jmp .give_neg
.give_neg:
    mov rax, rcx
    add rax, 2
    shl rax, 4
    lea r13, [token_array + rax]    ; the number token (the parser guarantees it)
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rsi, asm_minus
    mov rdx, 1
    call write_to_file
    mov rdi, [r13 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    add rcx, 2                      ; park on the number; .text_skip supplies the last step
    jmp .give_emit_jmp
.give_single:
    cmp byte [r12], 5
    je .give_lit
    jmp .give_var
; Phase 2 (give fix): give <a> <op> <b>  with op in + - * / %  and a, b identifiers or numbers.
; r12 = operand a, r8 = operator token, r9 = operand b. Result is left in rax, then the usual
; jump to the task epilogue. (Before this, "+ b" was silently dropped.)
.give_check_binop:
    mov rax, rcx
    add rax, 2
    cmp rax, [token_count]
    jge .give_single
    shl rax, 4
    lea r8, [token_array + rax]
    mov edx, [rbx + 4]
    cmp edx, [r8 + 4]
    jne .give_single
    cmp byte [r8], 3
    jne .give_single
    cmp byte [r8 + 1], 6
    je .give_binop
    cmp byte [r8 + 1], 7
    je .give_binop
    cmp byte [r8 + 1], 16
    je .give_binop
    cmp byte [r8 + 1], 17
    je .give_binop
    cmp byte [r8 + 1], 18
    je .give_binop
    jmp .give_single
.give_binop:
    mov rax, rcx
    add rax, 3
    shl rax, 4
    lea r9, [token_array + rax]
    ; load a into rax
    cmp byte [r12], 5
    je .gb_a_lit
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .gb_op
.gb_a_lit:
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
.gb_op:
    cmp byte [r8 + 1], 6
    je .gb_add
    cmp byte [r8 + 1], 7
    je .gb_sub
    ; '*', '/', '%': load b into rcx, apply
    cmp byte [r9], 5
    je .gb_b_rcx_lit
    mov rsi, asm_mov_rcx_l
    mov rdx, len_asm_mov_rcx_l
    call write_to_file
    mov rdi, [r9 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .gb_apply
.gb_b_rcx_lit:
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
.gb_apply:
    cmp byte [r8 + 1], 16
    je .gb_mul
    mov rsi, asm_div_seq
    mov rdx, len_asm_div_seq
    call write_to_file
    cmp byte [r8 + 1], 17
    je .gb_done
    mov rsi, asm_mod_fix
    mov rdx, len_asm_mod_fix
    call write_to_file
    jmp .gb_done
.gb_mul:
    mov rsi, asm_mul_line
    mov rdx, len_asm_mul_line
    call write_to_file
    jmp .gb_done
.gb_sub:
    cmp byte [r9], 5
    je .gb_sub_lit
    mov rsi, asm_sub_rax_l
    mov rdx, len_asm_sub_rax_l
    call write_to_file
    jmp .gb_b_var
.gb_sub_lit:
    mov rsi, asm_sub_rax_lit
    mov rdx, len_asm_sub_rax_lit
    call write_to_file
    jmp .gb_b_lit
.gb_add:
    cmp byte [r9], 5
    je .gb_add_lit
    mov rsi, asm_add_rax_l
    mov rdx, len_asm_add_rax_l
    call write_to_file
    jmp .gb_b_var
.gb_add_lit:
    mov rsi, asm_add_rax_lit
    mov rdx, len_asm_add_rax_lit
    call write_to_file
.gb_b_lit:
    mov rdi, [r9 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .gb_done
.gb_b_var:
    mov rdi, [r9 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.gb_done:
    add rcx, 3                      ; park on operand b; .text_skip supplies the last step
    jmp .give_emit_jmp
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

.handle_mold:
    ; `mold` blocks emit nothing (layout-only declaration, recorded by the
    ; parser). Skip the balanced `{...}` body: rcx is the mold token.
    mov r10, rcx
    xor r8, r8                      ; brace depth
.mold_skip:
    inc r10
    cmp r10, [token_count]
    jge .text_skip                  ; parser guarantees balance; defensive
    mov rax, r10
    shl rax, 4
    lea r13, [token_array + rax]
    cmp byte [r13], 3
    jne .mold_skip
    cmp byte [r13 + 1], 19          ; '{'?
    jne .mold_not_open
    inc r8
    jmp .mold_skip
.mold_not_open:
    cmp byte [r13 + 1], 20          ; '}'?
    jne .mold_skip
    dec r8
    cmp r8, 0
    jne .mold_skip
    mov rcx, r10                   ; park on '}': skip completes the step
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
.handle_gen:
    ; gen ( VALUE ). The parser has checked the shape (Phase 3), so the value is the token at rcx + 2.
    ;   string literal   written directly: sys write of str_N, length str_N_len (no zero byte)
    ;   number, true/false, or a name: the value goes into rax and a helper prints it by type
    ;                    (i32: decimal number, str: the text it points to, bool: true or false)
    mov rax, rcx
    add rax, 2
    mov r14, rax                    ; value token index (survives the emitting calls)
    shl rax, 4
    lea r12, [token_array + rax]
    cmp byte [r12], 6
    je .gen_string_lit
    cmp byte [r12], 5
    je .gen_number
    ; a name: its type decides how it is printed
    mov rdi, [r12 + 8]
    call find_symbol_scoped         ; rdx = symbol (the parser guarantees it exists)
    movzx eax, byte [rdx + 9]
    and eax, 0x7F
    mov [gen_cur_type], al
    mov rsi, asm_mov_rax_l
    mov rdx, len_asm_mov_rax_l
    call write_to_file
    mov rax, r14
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .gen_call_helper
.gen_number:
    mov byte [gen_cur_type], 1      ; i32
    cmp byte [r12 + 1], 1           ; written true/false: bool
    jne .gen_num_load
    mov byte [gen_cur_type], 14
.gen_num_load:
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rax, r14
    shl rax, 4
    lea r12, [token_array + rax]
    mov rdi, [r12 + 8]
    call get_strlen
    mov rdx, rax
    mov rsi, rdi
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.gen_call_helper:
    cmp byte [gen_cur_type], 2
    je .gen_call_str
    cmp byte [gen_cur_type], 14
    je .gen_call_bool
    or byte [gen_need], 1
    mov rsi, asm_call_gen_i32
    mov rdx, len_asm_call_gen_i32
    jmp .gen_call_emit
.gen_call_str:
    or byte [gen_need], 2
    mov rsi, asm_call_gen_str
    mov rdx, len_asm_call_gen_str
    jmp .gen_call_emit
.gen_call_bool:
    or byte [gen_need], 4
    mov rsi, asm_call_gen_bool
    mov rdx, len_asm_call_gen_bool
.gen_call_emit:
    call write_to_file
    add rcx, 3                      ; park on ')'
    jmp .text_skip
.gen_string_lit:
    ; Emit sys_write: mov rax,1; mov rdi,1; mov rsi,str; mov rdx,len; syscall   (r14 = the string token)
    mov rsi, asm_mov_rax_lit
    mov rdx, len_asm_mov_rax_lit
    call write_to_file
    mov rax, 1
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    call write_to_file
    mov rax, 1
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, r14
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    call write_to_file
    ; gen fix: length comes from the assembler (str_N_len), not from the source text,
    ; so escapes such as \n count as one byte and the terminating NUL is never written
    mov rsi, asm_str_prefix
    mov rdx, len_asm_str_prefix
    call write_to_file
    mov rax, r14
    call write_rax_to_file
    mov rsi, asm_str_len_ref
    mov rdx, len_asm_str_len_ref
    call write_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file

    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    add rcx, 3                      ; park on ')'
    jmp .text_skip
.handle_pull:
    ; `pull <operand>`: validated by the parser; the single-file bridge emits
    ; nothing. Consumes keyword + operand (add 1, skip completes +2).
    add rcx, 1
    jmp .text_skip
.handle_expose:
    ; `expose <name>`: validated by the parser (declared name); emits nothing.
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
    je .fold_inc_sel
    cmp byte [r8 + 1], 7            ; '-' -> dec; Phase 1.1b: '*','/','%'
    jne .no_incdec_fold             ; must NOT fold (v3=v3*1 wrongly emitted dec)
.fold_dec_sel:
    mov rsi, asm_dec
    mov rdx, len_asm_dec
    jmp .do_fold_write
.fold_inc_sel:
    mov rsi, asm_inc
    mov rdx, len_asm_inc
    jmp .do_fold_write
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
    ; Phase 1.3: token math. Value form is dest(0) =(1) sys(2) ((3) nr(4) ,(5)
    ; a1(6) ,(7) a2(8) ,(9) a3(10) )(11); the old 3/5/7/9 ignored '(' and
    ; crashed dharc (emit with null operand, truncated output.asm).
    mov rax, rcx
    add rax, 4
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
    add rax, 6
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 5
    je .sys_a_rdi_lit
    ; Phase 1.3: symbol-aware dispatch (was: always value-load, so a raw
    ; buffer arg passed content-as-pointer; locals also NASM-broke nowhere)
    push r14
    mov rdi, [r14 + 8]
    call find_symbol_scoped
    pop r14
    cmp rax, 1
    jne .sys_a_rdi_normal
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .sys_a_rdi_normal
    test byte [rdx + 9], 0x80
    jz .sys_a_rdi_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_rsi
.sys_a_rdi_addr:
    mov rsi, asm_mov_rdi_lit
    mov rdx, len_asm_mov_rdi_lit
    call write_to_file
    mov rdi, [r14 + 8]              ; Phase 1.4: mangled address
    call emit_mangled_name
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_a_rsi
.sys_a_rdi_normal:
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
    add rax, 8
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 6
    je .sys_a_rsi_str
    cmp byte [r14], 5
    je .sys_a_rsi_lit
    ; Phase 1.3: symbol-aware dispatch (was: address-immediate for every
    ; identifier, so scalar vars passed their address and locals NASM-broke)
    push r14
    mov rdi, [r14 + 8]
    call find_symbol_scoped
    pop r14
    cmp rax, 1
    jne .sys_a_rsi_normal
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .sys_a_rsi_normal
    test byte [rdx + 9], 0x80
    jz .sys_a_rsi_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_rdx
.sys_a_rsi_addr:
    mov rsi, asm_mov_rsi_lit
    mov rdx, len_asm_mov_rsi_lit
    call write_to_file
    mov rdi, [r14 + 8]              ; Phase 1.4: mangled address
    call emit_mangled_name
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_a_rdx
.sys_a_rsi_normal:
    mov rsi, asm_mov_rsi_l
    mov rdx, len_asm_mov_rsi_l
    call write_to_file
    mov rdi, [r14 + 8]
    call emit_named_operand
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_rdx
.sys_a_rsi_lit:
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
    add rax, 8
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
.sys_a_rdx:
    mov rax, rcx
    add rax, 10
    shl rax, 4
    lea r14, [token_array + rax]
    cmp byte [r14], 5
    je .sys_a_rdx_lit
    ; Phase 1.3: symbol-aware dispatch (same defect class as .sys_a_rdi)
    push r14
    mov rdi, [r14 + 8]
    call find_symbol_scoped
    pop r14
    cmp rax, 1
    jne .sys_a_rdx_normal
    mov al, [rdx + 9]
    and al, 0x7F
    cmp al, 3
    jne .sys_a_rdx_normal
    test byte [rdx + 9], 0x80
    jz .sys_a_rdx_addr
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
    mov rsi, asm_close_bracket_nl   ; lea closes with plain "]" (not the spill suffix)
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
    jmp .sys_a_emit
.sys_a_rdx_addr:
    mov rsi, asm_mov_rdx_lit
    mov rdx, len_asm_mov_rdx_lit
    call write_to_file
    mov rdi, [r14 + 8]              ; Phase 1.4: mangled address
    call emit_mangled_name
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    jmp .sys_a_emit
.sys_a_rdx_normal:
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
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, asm_mov_dest_rax
    mov rdx, len_asm_mov_dest_rax
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_close_rax
    mov rdx, len_asm_close_rax
    call write_to_file
    add rcx, 11                     ; consume dest..')' (12 tokens; text_skip adds 1)
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
    ; Phase 1.5a: bounds-check the index in rax against dest raw[N]
    ; (dest validated as raw by the parser; rbx = dest token)
    mov rdi, [rbx + 8]
    call emit_bounds_trap
    mov rsi, asm_mov1_byte
    mov rdx, len_asm_mov1_byte
    call write_to_file
    mov rdi, [rbx + 8]
    call emit_named_operand
    mov rsi, asm_array_store_byte
    mov rdx, len_asm_array_store_byte
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
    je .empty_loop
    cmp r13, 6                      ; Phase 1.6: cycle (1.6.2)
    je .empty_loop
    cmp r13, 7                      ; Phase 1.6: scan (1.6.2)
    je .empty_loop
    cmp r13, 1
    je .empty_when
    cmp r13, 5                      ; Phase 1.6: shift link at EOF
    je .empty_shift
    jmp .empty_end_common           ; kind 3 (consumed)
.empty_task_close:
    mov byte [in_task_flag], 0
    call emit_task_epilogue
    jmp .empty_do_cleanup
.empty_loop:
    ; Phase 1.6.2: scan links increment their counter slot (+24) first.
    cmp r13, 7
    jne .empty_no_inc
    mov rsi, asm_inc_rbp
    mov rdx, len_asm_inc_rbp
    call write_to_file
    mov rax, [r12 + 24]
    call write_rax_to_file
    mov rsi, asm_close_bracket_nl
    mov rdx, len_asm_close_bracket_nl
    call write_to_file
.empty_no_inc:
    call emit_jmp_start
    jmp .empty_end_common
.empty_when:
    call emit_fallback_label        ; dummy (no else branch)
    jmp .empty_end_common
.empty_shift:
    call emit_fallback_label        ; dummy F_new (unreferenced)
.empty_end_common:
    call emit_end_label             ; END_self
    cmp r13, 5                      ; Phase 1.6.2: +24 is a chain id only
    je .empty_chain_check           ; for shift links (and consumed ones);
    cmp r13, 3                      ; scans keep a counter slot there
    jne .empty_chain_done
.empty_chain_check:
    mov rax, [r12 + 24]             ; Phase 1.6: chain end unless own
    test rax, rax
    jz .empty_chain_done
    cmp rax, rdi
    je .empty_chain_done
    push rdi
    mov rdi, rax
    call emit_end_label
    pop rdi
.empty_chain_done:
    jmp .empty_do_cleanup
.empty_do_cleanup:
    mov r9w, [r12 + 8]
    call emit_scope_cleanup
    dec qword [cf_sp]
    jmp .empty_cf_stack

.write_exit:
    call emit_gen_helpers           ; Phase 3: the print routines the program calls, if any
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

emit_mangled_name:
    push rax
    push rdi
    push rsi
    push rdx
    mov rsi, asm_dhar_prefix
    mov rdx, len_asm_dhar_prefix
    call write_to_file
    pop rdx
    pop rsi
    pop rdi
    push rdi
    call get_strlen
    mov rdx, rax
    pop rsi
    call write_to_file
    pop rax
    ret

; ------------------------------------------------------------------------------
; Phase 1.5a emit_bounds_trap (Spec1 §14.4):
;   rdi = raw buffer name ptr. The index must already be in rax in the EMITTED
;   code. Emits: cmp rax,0; jl FAIL; cmp rax,N; jge FAIL; jmp OK;
;   FAIL: write message to stderr, exit(1); OK:
;   N comes from the symbol's array size (+24 text), or defaults to 8 for a
;   bare raw declaration. Preserves rbx, rcx, r8-r15; uses rax/rdi/rsi/rdx.
; ------------------------------------------------------------------------------
emit_bounds_trap:
    push rbx
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    call find_symbol_scoped         ; rdi = name; rax?/rdx = sym
    mov r14, 8                      ; default N = 8 (bare raw / unknown)
    cmp rax, 1
    jne .ebt_have_n
    mov rsi, [rdx + 24]
    test rsi, rsi
    jz .ebt_have_n
    push rdx
    mov rdi, rsi
    call parse_uint                 ; rax = N
    mov r14, rax
    pop rdx
.ebt_have_n:
    mov r13, [label_id_counter]
    inc qword [label_id_counter]
    mov rsi, asm_cmp_rax_zero
    mov rdx, len_asm_cmp_rax_zero
    call write_to_file
    mov rsi, asm_jl_trap
    mov rdx, len_asm_jl_trap
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rsi, asm_cmp_rax
    mov rdx, len_asm_cmp_rax
    call write_to_file
    mov rax, r14
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rsi, asm_jge_trap
    mov rdx, len_asm_jge_trap
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rsi, asm_jmp_trap_ok
    mov rdx, len_asm_jmp_trap_ok
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, newline
    mov rdx, 1
    call write_to_file
    mov rsi, asm_trap_lbl
    mov rdx, len_asm_trap_lbl
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    mov rsi, asm_mov_rax_one
    mov rdx, len_asm_mov_rax_one
    call write_to_file
    mov rsi, asm_mov_rdi_two
    mov rdx, len_asm_mov_rdi_two
    call write_to_file
    mov rsi, asm_mov_rsi_trap
    mov rdx, len_asm_mov_rsi_trap
    call write_to_file
    mov rsi, asm_mov_rdx_trap_len
    mov rdx, len_asm_mov_rdx_trap_len
    call write_to_file
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, asm_mov_rax_60
    mov rdx, len_asm_mov_rax_60
    call write_to_file
    mov rsi, asm_mov_rdi_one
    mov rdx, len_asm_mov_rdi_one
    call write_to_file
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, asm_trap_ok_lbl
    mov rdx, len_asm_trap_ok_lbl
    call write_to_file
    mov rax, r13
    call write_rax_to_file
    mov rsi, asm_colon_nl
    mov rdx, len_asm_colon_nl
    call write_to_file
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; V0.3.0 emit_named_operand:
;   rdi = identifier string. Writes the mangled label text for globals, or
;   "rbp-<offset>" for task-local symbols. Preserves all caller registers.
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; Phase 3 emit_gen_helpers: at the end of the program, add the routines that gen() called
; (bit 0 i32, bit 1 str, bit 2 bool of gen_need). A program that never prints a value gets none,
; so its size does not change. The sys call text is the target's own (syscall, or the Windows stub).
; Touches only rsi and rdx (r15, the output file, is read by write_to_file).
; ------------------------------------------------------------------------------
emit_gen_helpers:
    test byte [gen_need], 1
    jz .egh_str
    mov rsi, gen_i32_a
    mov rdx, len_gen_i32_a
    call write_to_file
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, gen_i32_b
    mov rdx, len_gen_i32_b
    call write_to_file
.egh_str:
    test byte [gen_need], 2
    jz .egh_bool
    mov rsi, gen_str_a
    mov rdx, len_gen_str_a
    call write_to_file
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, gen_str_b
    mov rdx, len_gen_str_b
    call write_to_file
.egh_bool:
    test byte [gen_need], 4
    jz .egh_done
    mov rsi, gen_bool_a
    mov rdx, len_gen_bool_a
    call write_to_file
    mov rsi, [cur_syscall_ptr]
    mov rdx, [cur_syscall_len]
    call write_to_file
    mov rsi, gen_bool_b
    mov rdx, len_gen_bool_b
    call write_to_file
.egh_done:
    ret

emit_named_operand:
    push rax
    push rdi
    push rsi
    push rdx
    push r8
    push r13
    mov r8, rdi                     ; name ptr (find_symbol preserves r8)
    mov r13, rdi
    call find_symbol_scoped
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
    mov rdi, r8                     ; Phase 1.4: dhar_ prefix (NASM-safe)
    call emit_mangled_name
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

; ------------------------------------------------------------------------------
; Phase 1.5a parse_uint:
;   rdi = NUL-terminated ASCII digits (array size text). Returns rax = value.
;   Stops at first non-digit. Preserves rdi/rdx/rbx/rcx/rsi; clobbers rax.
; ------------------------------------------------------------------------------
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
