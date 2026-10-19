section .text

extern __errno_location
global ft_read

ft_read:
        mov eax, 0
        syscall
        test rax, rax
        js .error
        ret

.error:
        neg rax
        ;currently 8-byte because ft_read function call
        ;save error code and align to rsp's required 16-byte before call. 
        push rax
        call __errno_location wrt ..plt
        pop rdi
        mov [rax], edi
        mov rax, -1
        ret

section .note.GNU-stack noalloc noexec nowrite progbits
