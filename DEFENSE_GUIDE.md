# 42 `libasm` Defense & Rewrite-From-Scratch Guide

Use this guide when **practicing rewriting the 7 functions from scratch** or **reviewing right before your 42 peer evaluation**.

---

## 1. The 60-Second Master Cheat Sheet

### System V AMD64 ABI Register Map
```text
Arguments (in order):   1st: rdi   2nd: rsi   3rd: rdx   4th: rcx   5th: r8    6th: r9
Return Value:           rax (64-bit pointer / size_t / ssize_t) | eax (32-bit int)
Caller-Saved (Scratch): rax, rdi, rsi, rdx, rcx, r8, r9, r10, r11  (freely overwritten)
Callee-Saved (Must Save): rbx, rbp, r12, r13, r14, r15, rsp        (must restore before ret)
```

### Register Sub-Sizes & The 32-Bit Zero-Extension Rule
| 64-bit (`qword`, 8B) | 32-bit (`dword`, 4B) | 16-bit (`word`, 2B) | 8-bit (`byte`, 1B) |
| :--- | :--- | :--- | :--- |
| `rax` (Return / Syscall #) | `eax` | `ax` | `al` |
| `rdi` (Arg 1) | `edi` | `di` | `dil` |
| `rsi` (Arg 2) | `esi` | `si` | `sil` |
| `rdx` (Arg 3 / `mul` high) | `edx` | `dx` | `dl` |
| `rcx` (Arg 4 / Counter) | `ecx` | `cx` | `cl` |

> [!IMPORTANT]
> - Writing to a **32-bit** register (`xor eax, eax` or `mov eax, 1`) **automatically zeroes the upper 32 bits** of the 64-bit register (`rax`).
> - Writing to an **8-bit (`al`)** or **16-bit (`ax`)** register **leaves the upper bits untouched (garbage remains!)**. Use `movzx eax, al` to zero-extend 8 bits into 32/64 bits.

### CPU Flags (`eflags`) & Jumps Used in `libasm`
| Flag | Name | Set When... | Conditional Jumps |
| :--- | :--- | :--- | :--- |
| **`ZF`** | Zero Flag | Result of operation is `0` (or `cmp a, b` where `a == b`) | `je` / `jz` (`ZF=1`), `jne` / `jnz` (`ZF=0`) |
| **`SF`** | Sign Flag | Result is negative (most significant bit is `1`) | `js` (`SF=1`, negative), `jns` (`SF=0`) |
| **`CF`** | Carry Flag | Unsigned arithmetic overflow / borrow (e.g., `mul` overflows 64 bits) | `jc` / `jb` (`CF=1`), `jnc` (`CF=0`) |
| **`OF`** | Overflow Flag | Signed arithmetic two's-complement overflow | `jo` (`OF=1`), `jl` (`SF!=OF`), `jg` (`ZF=0 & SF=OF`) |

---

## 2. Rewriting Each Function From Scratch (Mental Recipes)

Try rewriting each `.s` file using only the **Mental Recipe** column first, then check your work against the **Key Instructions**!

### 1. [`ft_strlen.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_strlen.s) — `size_t ft_strlen(const char *s)`
- **Inputs**: `rdi` = `s`
- **Output**: `rax` = length (`size_t`, 64-bit)
- **Mental Recipe**:
  1. Set counter `rax = 0` (`xor eax, eax`).
  2. In `.loop`: compare the byte at `[rdi + rax]` with `0` (`cmp byte [rdi + rax], 0`).
  3. If equal (`je .done`), return (`ret`).
  4. Otherwise increment `rax` (`inc rax`) and jump back (`jmp .loop`).

### 2. [`ft_strcpy.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_strcpy.s) — `char *ft_strcpy(char *dst, const char *src)`
- **Inputs**: `rdi` = `dst`, `rsi` = `src`
- **Output**: `rax` = `dst`
- **Mental Recipe**:
  1. Set index `rcx = 0` (`xor ecx, ecx`).
  2. In `.loop`:
     - Copy 1 byte from `src` to `dst` via 8-bit `dl` (`mov dl, [rsi + rcx]` then `mov [rdi + rcx], dl`).
     - Check if the byte we just copied was `'\0'` (`test dl, dl` $\rightarrow$ `je .done`). *(Because we copied first, `'\0'` is already written to `dst`!)*
     - Increment `rcx` (`inc rcx`) and repeat (`jmp .loop`).
  3. In `.done`: put original `dst` into `rax` (`mov rax, rdi`) and `ret`.

### 3. [`ft_strcmp.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_strcmp.s) — `int ft_strcmp(const char *s1, const char *s2)`
- **Inputs**: `rdi` = `s1`, `rsi` = `s2`
- **Output**: `eax` = `(unsigned char)s1[i] - (unsigned char)s2[i]` (32-bit signed `int`)
- **Mental Recipe**:
  1. Set index `rcx = 0` (`xor ecx, ecx`).
  2. In `.loop`:
     - Load `al = [rdi + rcx]` and `dl = [rsi + rcx]`.
     - If `al != dl`, stop (`cmp al, dl` $\rightarrow$ `jne .done`).
     - If `al == 0` (meaning both reached `'\0'`), stop (`test al, al` $\rightarrow$ `je .done`).
     - Increment `rcx` (`inc rcx`) and repeat (`jmp .loop`).
  3. In `.done`:
     - Zero-extend both unsigned bytes (`0..255`) to 32-bit `int`s: `movzx eax, al` and `movzx edx, dl`.
     - Subtract in 32-bit (`sub eax, edx`) and `ret`.

### 4 & 5. [`ft_write.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_write.s) & [`ft_read.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_read.s)
- **Inputs**: `rdi` = `fd`, `rsi` = `buf`, `rdx` = `count` *(already matching Linux `syscall` registers!)*
- **Output**: `rax` = bytes transferred (`>= 0`) or `-1` on error (with `errno` set).
- **Mental Recipe**:
  1. Declare `extern __errno_location` at the top.
  2. Set `eax = 1` (for `ft_write`) or `eax = 0` (for `ft_read`), and execute `syscall`.
  3. Check if `rax < 0` (`test rax, rax` $\rightarrow$ `js .error`). If not negative, `ret`!
  4. In `.error`:
     - Linux kernel returned `-errno` in `rax`, so negate it (`neg rax`).
     - Save `rax` on the stack **and** align `rsp` to 16 bytes (`push rax`).
     - Call `call __errno_location wrt ..plt` (returns `int *` address of `errno` in `rax`).
     - Pop the saved error code into `rdi` (`pop rdi`).
     - Store 32-bit `edi` into `*rax` (`mov [rax], edi`).
     - Set `rax = -1` (`mov rax, -1`) and `ret`.

### 6. [`ft_strdup.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_strdup.s) — `char *ft_strdup(const char *s)`
- **Inputs**: `rdi` = `s`
- **Output**: `rax` = newly allocated copy of `s` (or `NULL` if `malloc` fails)
- **Mental Recipe**:
  1. Declare `extern malloc`, `extern ft_strlen`, `extern ft_strcpy`.
  2. `push rdi` (saves `s` on the stack **and** aligns `rsp % 16 == 0` for `call`!).
  3. `call ft_strlen` (`rax` = length of `s`).
  4. Add 1 for `'\0'` (`inc rax`), move into 1st arg (`mov rdi, rax`), and `call malloc wrt ..plt`.
  5. Restore `s` from the stack into `rsi` (the 2nd arg for `ft_strcpy`!) via `pop rsi`.
  6. Check if `malloc` returned `NULL`: `test rax, rax` $\rightarrow$ `jz .done`.
  7. Move allocated `dst` pointer (`rax`) into 1st arg (`mov rdi, rax`), `call ft_strcpy`, and `ret`.

### 7. [`ft_calloc.s`](file:///home/naokiiida/Documents/workspace/libasm/ft_calloc.s) — `void *ft_calloc(size_t nmemb, size_t size)`
- **Inputs**: `rdi` = `nmemb`, `rsi` = `size`
- **Output**: `rax` = pointer to zeroed memory of `nmemb * size` bytes (or `NULL` + `errno = ENOMEM`)
- **Mental Recipe**:
  1. Declare `extern malloc`, `extern __errno_location`.
  2. Multiply `nmemb * size` using unsigned 128-bit multiply: `mov rax, rdi` then `mul rsi` (`rdx:rax = rax * rsi`).
  3. If `rdx != 0`, `mul` sets `CF = 1`: `jc .overflow`.
  4. Save `total_bytes` (`rax`) and align stack: `push rax`.
  5. Pass `total_bytes` to `malloc`: `mov rdi, rax` then `call malloc wrt ..plt`.
  6. Pop `total_bytes` into `rcx` (`pop rcx`), check `test rax, rax` $\rightarrow$ `jz .done`.
  7. Zero-fill `[rax + rdx]` for `rdx = 0 .. rcx - 1` (`xor edx, edx`, loop with `cmp rcx, rdx` / `je .done`, `mov byte [rax + rdx], 0`, `inc rdx`).
  8. In `.overflow`: `push rax` (align stack), `call __errno_location wrt ..plt`, `pop rdi`, `mov dword [rax], 12` (`ENOMEM`), `xor eax, eax` (`return NULL`), `ret`.

### 8. silence execution stack warning
  ```nasm
      ; --- Place at the very end of the file ---
      section .note.GNU-stack noalloc noexec nowrite progbits
  ```

  1. Section switching in NASM: In NASM, writing section <name> switches the active section for all
  following declarations. If you put it at the top and forget to re-declare section .text, your
  assembly instructions would be assembled into the .note.GNU-stack section instead of .text.
  2. What the flags mean:
      • noalloc: This section is not loaded into memory when the program runs.
      • noexec: The stack page must not have execute permission (PROT_EXEC is cleared).
      • nowrite: Read-only metadata.
      • progbits: Contains program information for the ELF linker.
  3. The result: GNU ld inspects this note across all .o files in libasm.a. Seeing noexec on all
  objects allows ld to emit an ELF binary with GNU_STACK permissions RW instead of RWE (executable
  stack), eliminating the warning:
  > /usr/bin/ld: warning: ... has a LOAD segment with executable stack

---

## 3. Classic 42 Defense Questions & Answers

| Evaluator Question | Exact Answer to Give |
| :--- | :--- |
| **"Why can't you do `mov [rdi], [rsi]` or `cmp [rdi], [rsi]`?"** | x86-64 machine instructions only have a single `ModR/M` memory-addressing field, so at most **one** operand can be a memory location (`[...]`). Moving data from RAM to RAM must go through a CPU register (`mov dl, [rsi]` $\rightarrow$ `mov [rdi], dl`). |
| **"Why do you need `movzx` in `ft_strcmp`? Why not `sub al, dl`?"** | `man 3 strcmp` requires comparing bytes as **`unsigned char` (`0..255`)** and returning a **32-bit signed `int` (`eax`)**. If we compare `0x01` (`1`) and `0xFF` (`255`), 8-bit `sub al, dl` wraps around to `0x02` (`+2`, wrong sign!). Zero-extending both to 32 bits first (`movzx eax, al` and `movzx edx, dl`) computes `1 - 255 = -254` in 32-bit signed `eax`. |
| **"Why must `rsp` be 16-byte aligned before `call`?"** | The System V AMD64 ABI requires `rsp % 16 == 0` right before any `call` instruction because `glibc` functions use 16-byte SSE instructions (`movaps`) on the stack that segfault if unaligned. When our function is entered, `call` pushed an 8-byte return address onto the stack (`rsp % 16 == 8`). Doing one `push` (`rsp -= 8`) before an inner `call` aligns `rsp` back to a multiple of 16 (`rsp % 16 == 0`). |
| **"Why do you call `__errno_location` instead of accessing a global `errno`?"** | In modern multi-threaded C (`pthread`), each thread has its own private `errno` in Thread-Local Storage so threads don't overwrite each other's error codes. `__errno_location()` returns the `int *` pointer to the calling thread's `errno`. |
| **"Why `mov [rax], edi` (or `dword`) when setting `errno`?"** | `__errno_location()` returns `int *` in `rax`. On 64-bit Linux, a C `int` is **32 bits (4 bytes = `dword`)**, not 64 bits (`qword`). Writing 64-bit `rdi` would overwrite 4 bytes of adjacent memory past `errno`! |
| **"What does `wrt ..plt` mean?"** | **"With Reference To Procedure Linkage Table."** External functions like `malloc` and `__errno_location` live in the shared C library (`libc.so.6`), whose address is randomized at runtime (ASLR). `wrt ..plt` tells NASM to emit a `PLT32` relocation so the call jumps through the executable's PLT trampoline stub. |
| **"How does `mul rsi` detect overflow in `ft_calloc`?"** | `mul rsi` multiplies unsigned 64-bit `rax * rsi` into a **128-bit** result across `rdx:rax` (high 64 bits in `rdx`, low 64 bits in `rax`). If the product exceeds 64 bits (`size_t` max), `rdx` is non-zero and the CPU sets the Carry Flag (`CF = 1`), which we catch with `jc .overflow`. |
| **"What does `ar rcs libasm.a` in the Makefile do?"** | `ar` creates a static library archive (`.a`) from `.o` object files: `r` replaces/inserts object files, `c` creates the archive if it doesn't exist, and `s` writes the symbol table index (same as `ranlib`). |
