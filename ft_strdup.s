extern malloc
extern ft_strlen
extern ft_strcpy

section .text
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
	call ft_strcpy
	; je .done	;not needed because .done is next instruction anyway
	; could have also gone with jmp ft_strcpy for tail call optimization

.done:
	ret
