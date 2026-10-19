section .text
global ft_strlen

ft_strlen:
    ; TODO: rax を 0 にする(カウンタ)
    xor eax, eax
.loop:
    ; TODO: rdi[rax] が 0 かどうか比較
    cmp byte[rdi + rax], 0
    ; TODO: 0 ならZF ゼロフラグで .done へ
    je .done
    ; TODO: rax を 1 増やして .loop へ
    inc rax
    jmp .loop
.done:
    ret

; ft_strlen:
;     mov rax, -1
; .loop:
;     cmp byte[rdi + rax + 1], 0
;     ; TODO: rax を 1 増やして .loop へ
;     lea     rax, [rax + 1]          ; advances rax WITHOUT modifying CPU flags
;     jne .loop
; .done:
;     ret

section .note.GNU-stack noalloc noexec nowrite progbits
