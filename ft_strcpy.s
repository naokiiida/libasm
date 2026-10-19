section .text
global ft_strcpy

ft_strcpy:
        xor ecx, ecx

.loop:
        mov dl, [rsi + rcx]
        mov [rdi + rcx], dl
        test dl, dl
        je .done
        inc rcx
        jmp .loop

.done:
        mov rax, rdi
        ret

; ft_strcpy:
;         xor ecx, ecx

; .loop:
;         cmp byte[rsi + rcx], 0
;         je .done
;         mov dl, [rsi + rcx]
;         mov [rdi + rcx], dl
;         inc rcx
;         jmp .loop

; .done:
;         mov byte[rdi + rcx], 0
;         mov rax, rdi
;         ret

section .note.GNU-stack noalloc noexec nowrite progbits
