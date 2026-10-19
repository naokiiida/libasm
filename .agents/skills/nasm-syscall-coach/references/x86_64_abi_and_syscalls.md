# x86-64 System V AMD64 ABI, Syscalls & `libasm` Reference

## 1. General-Purpose Registers & Sub-Registers

Writing to a **32-bit** register (e.g., `mov eax, 1` or `xor eax, eax`) **automatically zero-extends** the upper 32 bits of the 64-bit register (`rax`). Writing to 16-bit (`ax`) or 8-bit (`al`) registers **does NOT** modify the upper bits!

| 64-bit | 32-bit | 16-bit | 8-bit Low | Role in System V AMD64 ABI | Preserved across `call`? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `rax` | `eax` | `ax` | `al` | Return value / Syscall number | No (Caller-saved) |
| `rdi` | `edi` | `di` | `dil` | 1st Argument | No (Caller-saved) |
| `rsi` | `esi` | `si` | `sil` | 2nd Argument | No (Caller-saved) |
| `rdx` | `edx` | `dx` | `dl` | 3rd Argument / 2nd Return / `mul` high | No (Caller-saved) |
| `rcx` | `ecx` | `cx` | `cl` | 4th Argument (C) / Clobbered by `syscall` | No (Caller-saved) |
| `r8` | `r8d` | `r8w` | `r8b` | 5th Argument | No (Caller-saved) |
| `r9` | `r9d` | `r9w` | `r9b` | 6th Argument | No (Caller-saved) |
| `r10` | `r10d` | `r10w` | `r10b` | 4th Argument (`syscall`) / Scratch | No (Caller-saved) |
| `r11` | `r11d` | `r11w` | `r11b` | Clobbered by `syscall` / Scratch | No (Caller-saved) |
| `rbx` | `ebx` | `bx` | `bl` | General Purpose | **Yes (Callee-saved)** |
| `rbp` | `ebp` | `bp` | `bpl` | Frame Pointer / General Purpose | **Yes (Callee-saved)** |
| `r12`–`r15` | `r12d`–`r15d` | `r12w`–`r15w` | `r12b`–`r15b` | General Purpose | **Yes (Callee-saved)** |
| `rsp` | `esp` | `sp` | `spl` | Stack Pointer | **Yes (Callee-saved)** |

---

## 2. Stack Alignment Rule (`rsp % 16 == 0` before `call`)

1. Before a caller executes `call func`, `rsp` is a multiple of 16 (`rsp % 16 == 0`).
2. `call func` pushes the 8-byte return address (`rip`) onto the stack, so at the first instruction of `func`, **`rsp % 16 == 8`**.
3. If `func` is a **leaf function** (does not execute `call`), `rsp` does not need to be adjusted.
4. If `func` executes `call` (e.g., `malloc`, `free`, `__errno_location`, `cmp`), `rsp` **must** be reduced by `8 + 16*k` bytes before the `call`:
   - Pushing **1** (or 3, 5) 64-bit register(s) (e.g., `push rbx` or `push rbp`) makes `rsp % 16 == 0`.
   - Pushing **2** (or 4) 64-bit registers leaves `rsp % 16 == 8`, requiring `sub rsp, 8` before `call`.

---

## 3. Linux x86-64 `syscall` & `errno` Pattern

| Syscall | `rax` | `rdi` | `rsi` | `rdx` | Return (`rax`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `sys_read` | `0` | `int fd` | `void *buf` | `size_t count` | Bytes read (`>= 0`) or `-errno` (`< 0`) |
| `sys_write` | `1` | `int fd` | `const void *buf` | `size_t count` | Bytes written (`>= 0`) or `-errno` (`< 0`) |

### `errno` Handling Blueprint (Conceptual)
1. Execute `syscall`.
2. Check if `rax < 0` (`test rax, rax` then `js .error`).
3. In `.error`:
   - Negate `rax` to get positive error code (`neg rax`).
   - Save the error code across the function call (e.g., `push rax` — note this aligns `rsp` by 8 bytes if no other pushes were made!).
   - Call `extern __errno_location` via PLT: `call __errno_location wrt ..plt`.
   - Pop the saved error code into a scratch register (`pop rdi`) and store **32 bits** (`edi`) into `[rax]`: `mov [rax], edi`.
   - Set `rax` to `-1` (`mov rax, -1`) and `ret`.

---

## 4. Mandatory Function Notes

- **`ft_strlen(const char *s)`**:
  - `rdi = s`. Count bytes until `byte [rdi + rax] == 0`. Return `rax`.
- **`ft_strcpy(char *dst, const char *src)`**:
  - `rdi = dst`, `rsi = src`. Copy bytes including the terminating `'\0'`. Return original `dst` in `rax`.
- **`ft_strcmp(const char *s1, const char *s2)`**:
  - `rdi = s1`, `rsi = s2`. Compare `unsigned char` by `unsigned char` until mismatch or `'\0'`.
  - Use `movzx eax, al` and `movzx edx, dl`, then `sub eax, edx` so the 32-bit return value in `eax` has the right sign.
- **`ft_strdup(const char *s)`**:
  - Save `rdi` (`s`), compute `len = ft_strlen(s)`, allocate `len + 1` bytes with `call malloc wrt ..plt`.
  - If `rax == 0` (`NULL`), return `0` (`malloc` already sets `errno = ENOMEM`).
  - Copy `s` into the newly allocated buffer (`ft_strcpy`) and return the buffer pointer in `rax`.
- **`ft_calloc(size_t nmemb, size_t size)`**:
  - `rdi = nmemb`, `rsi = size`.
  - Compute `rax = rdi * rsi` using unsigned `mul rsi` (which multiplies `rax * rsi -> rdx:rax`).
  - If `CF == 1` (`jc .overflow`), set `errno = ENOMEM` (`12`) via `__errno_location wrt ..plt` and return `0` (`NULL`).
  - Otherwise call `malloc wrt ..plt` with total bytes (`rdi = rax`), check for `NULL`, zero-fill the allocated bytes, and return pointer in `rax`.

---

## 5. Bonus Function Notes

### Linked List Structure (`t_list`)
```nasm
; struct s_list {
;     void          *data;  ; [reg + 0] (qword, 8 bytes)
;     struct s_list *next;  ; [reg + 8] (qword, 8 bytes)
; };                        ; total size = 16 bytes
```
- **`ft_list_push_front(t_list **begin_list, void *data)`**:
  - `rdi = begin_list`, `rsi = data`. Check `test rdi, rdi` (`jz .done`).
  - Allocate 16 bytes (`mov rdi, 16`, `call malloc wrt ..plt`).
  - Set `[rax + 0] = data`, `[rax + 8] = *begin_list`, `*begin_list = rax`.
- **`ft_list_size(t_list *begin_list)`**:
  - Traverse `rdi = [rdi + 8]` while `rdi != 0`, incrementing `eax`. Return `eax`.
- **`ft_list_sort(t_list **begin_list, int (*cmp)())`**:
  - `rdi = begin_list`, `rsi = cmp`. Calls `cmp(node1->data, node2->data)` (`rdi = data1`, `rsi = data2`).
  - If `eax > 0` (`cmp` returns signed 32-bit `int` in `eax`, check `cmp eax, 0` / `jg`), swap `node1->data` and `node2->data` (or relink nodes).
- **`ft_list_remove_if(t_list **begin_list, void *data_ref, int (*cmp)(), void (*free_fct)(void *))`**:
  - `rdi = begin_list`, `rsi = data_ref`, `rdx = cmp`, `rcx = free_fct`.
  - When `cmp(curr->data, data_ref) == 0` (`test eax, eax` / `jz`), call `free_fct(curr->data)`, unlink `curr`, and `call free wrt ..plt` on `curr`.
- **`ft_atoi_base(char *str, char *base)`**:
  - Validate `base`: length >= 2, no whitespace (`9..13`, `32`), no `'+'` (`43`) or `'-'` (`45`), no duplicate characters. Return `0` if invalid.
  - Skip leading whitespace in `str`, accumulate sign from `'+'`/`'-'`, convert base digits until non-base char, return signed 32-bit result in `eax`.
- **`ft_simd_memchr(const void *s, int c, size_t n)`**:
  - `rdi = s`, `esi = c` (low byte `sil`), `rdx = n`.
  - Broadcast `sil` across 16-byte XMM register (`movd xmm1, esi` + `punpcklbw xmm1, xmm1` + `pshufd xmm1, xmm1, 0`) or 32-byte YMM register.
  - Care with page boundaries: handle leading bytes up to 16-byte alignment `(rdi & 15)` so `movdqa` never crosses an unmapped page boundary!
  - Use `pcmpeqb` + `pmovmskb` + `tzcnt`/`bsf` to locate the first matching byte offset.
