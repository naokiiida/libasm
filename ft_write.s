section .text

extern __errno_location
global ft_write

ft_write:
        mov eax, 1
        syscall
        test rax, rax
        js .error
        ret

.error:
        neg rax
        push rax
        call __errno_location wrt ..plt
        pop rdi
        mov [rax], edi
        mov rax, -1
        ret

section .note.GNU-stack noalloc noexec nowrite progbits
