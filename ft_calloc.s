section .text

extern malloc
extern __errno_location

global ft_calloc

ft_calloc:
	mov rax, rdi
	mul rsi
	jc .overflow
	push rax
	mov rdi, rax
	call malloc wrt ..plt
	pop rcx
	test rax, rax
	jz .done
	xor edx, edx
	; jmp .loop ;not needed since .loop instruction is right below

.loop:
	cmp rcx, rdx
	je .done
	mov byte[rax+rdx],0
	inc rdx
	jmp .loop

.done:
	ret

.overflow:
	push rax
	call __errno_location wrt ..plt
	pop rdi
	; int errno -> dword (32bit)
	mov dword[rax], 12 ;errno = ENOMEM (12)
	xor eax, eax
	ret

section .note.GNU-stack noalloc noexec nowrite progbits
