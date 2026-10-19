section .text
global ft_strcmp

ft_strcmp:
	xor ecx, ecx

.loop:
	mov al, [rdi + rcx]
	mov dl, [rsi + rcx]
	cmp al, dl
	jne .done
	test al, al
	je .done
	inc rcx
	jmp .loop

.done:
	movzx eax, al
	movzx edx, dl
	sub eax, edx
	ret

section .note.GNU-stack noalloc noexec nowrite progbits
