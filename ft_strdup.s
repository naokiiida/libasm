section .text

extern malloc
extern ft_strlen
extern ft_strcpy

global ft_strdup

ft_strdup:
	;16-byte align to prep for call and also save arg0 pointer to stack
	push rdi
	call ft_strlen
	;+1 for '\0'
	inc rax
	mov rdi, rax
	call malloc wrt ..plt
	pop rsi
	test rax, rax
	jz .done
	mov rdi, rax
	;rsi is arg1 for strcpy
	jmp ft_strcpy ;tail call optimization instead of `call ft_strcpy` and `.done: ret`

.done:
	ret

section .note.GNU-stack noalloc noexec nowrite progbits
