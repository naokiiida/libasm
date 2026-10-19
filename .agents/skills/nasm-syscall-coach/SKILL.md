---
name: nasm-syscall-coach
description: >-
  Use this skill when coaching the user on x86-64 NASM assembly, reviewing .s files,
  explaining CPU flags, registers, System V AMD64 ABI calling conventions, Linux syscalls,
  errno handling (__errno_location), linked list struct offsets, or SIMD instructions for 42 libasm.
---

# 42 `libasm` NASM & Syscall Coach

Use this skill to guide the user through designing, reviewing, and debugging x86-64 assembly in Intel syntax (`nasm -f elf64`) for the 42 `libasm` project.

## Reference Manual

Read [references/x86_64_abi_and_syscalls.md](./references/x86_64_abi_and_syscalls.md) whenever you need exact details on:
- Register sub-sizing (`rax`/`eax`/`ax`/`al`) and zero-extension rules
- System V AMD64 ABI calling convention & 16-byte stack alignment
- Linux syscall numbers, registers, and `__errno_location wrt ..plt` workflow
- Mandatory function specifications (`ft_strlen`, `ft_strcpy`, `ft_strcmp`, `ft_write`, `ft_read`, `ft_strdup`, `ft_calloc`)
- Bonus function specifications (`t_list` layout, `ft_atoi_base`, `ft_list_*`, `ft_simd_memchr`)

## Coaching Workflow

1. **Inspect Without Spoiling**:
   - View the user's `.s` file.
   - Check each instruction against the System V AMD64 ABI and NASM syntax rules.
   - Unless the user explicitly requests complete code, highlight the exact line or concept that needs attention and ask a guiding question or show a 1–2 line syntax example.

2. **Common Pitfalls to Check in Every `.s` File**:
   - **Invalid NASM operands**: e.g., `inc 1` (cannot increment an immediate; must be `inc rax`), `cmp [rdi], 0` without size specifier (`byte [rdi]`), or memory-to-memory `mov [rdi], [rsi]` (x86 does not allow two memory operands in `mov`/`cmp`).
   - **32-bit vs 64-bit return types**:
     - `ft_strcmp`, `ft_atoi_base`, `ft_list_size` return `int` (32-bit signed in `eax`), whereas `ft_strlen`, `ft_write`, `ft_read` return 64-bit (`rax`), and `ft_strcpy`, `ft_strdup`, `ft_calloc`, `ft_simd_memchr` return 64-bit pointers (`rax`).
     - In `ft_strcmp`, characters must be compared as **`unsigned char`** (`movzx eax, byte [rdi + rcx]`, `movzx edx, byte [rsi + rcx]`, `sub eax, edx`).
   - **Caller-saved clobbering across `call`**:
     - `rdi`, `rsi`, `rdx`, `rcx`, `r8`–`r11`, `rax` are **destroyed** by `call malloc wrt ..plt`, `call __errno_location wrt ..plt`, `call cmp`, or `call free_fct`.
     - Preserve needed pointers/lengths on the 16-byte-aligned stack or in callee-saved registers (`rbx`, `rbp`, `r12`–`r15` — which themselves must be saved/restored).
   - **Syscall `errno` handling (`ft_write`, `ft_read`)**:
     - Linux `syscall` returns `-errno` in `rax` when `rax < 0` (`test rax, rax` followed by `js .error`).
     - `neg rax` converts `-errno` to positive `errno`.
     - `__errno_location` returns `int *` in `rax`. Store a **32-bit** value (`mov [rax], edi` or `mov dword [rax], ebx`), **not** 64-bit `mov [rax], rdi`!
   - **`ft_calloc(nmemb, size)` overflow check**:
     - `mov rax, rdi` then `mul rsi` (unsigned 64x64 -> 128-bit in `rdx:rax`).
     - `mul` sets `CF=1` and `OF=1` if `rdx != 0` (64-bit overflow). Check with `jc .overflow` (or `jo .overflow`).

3. **Looking up Linux Man Pages in `nix develop`**:
   If you or the user want to verify exact standard library semantics, run:
   ```bash
   nix develop --command man 2 write | col -b
   ```
