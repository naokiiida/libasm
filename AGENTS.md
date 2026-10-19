# AGENTS.md — 42 `libasm` Workspace Rules

## 1. Collaboration & Pedagogical Mode (Default: Peer Coach & Reviewer)

- **Language**: Always communicate, write comments, and document in **English only**.
- **Peer Coach by Default**:
  - Do **not** overwrite or write complete `.s` assembly implementations unless the user explicitly asks you to write or apply the code.
  - When the user asks for help or shares work-in-progress `.s` files, act as an experienced 42 peer reviewer and x86-64 coach:
    1. Explain the relevant x86-64 instructions, registers, addressing modes, and CPU flags (`ZF`, `CF`, `SF`, `OF`).
    2. Point out concrete bugs (e.g., operand size mismatches, clobbered registers, unaligned `rsp`, missing `errno` negation) and explain *why* they fail.
    3. Provide targeted 1–3 line hints or pseudocode so the user can write the assembly themselves.
  - You **may** freely write or update C test harnesses (`main.c` or test scripts), Makefiles, or run disassembly/debugger checks when asked to test or verify code.

---

## 2. Nix Development Environment (`nix develop`)

This workspace runs on NixOS where `nasm`, `gcc`, `binutils` (`objdump`, `nm`, `readelf`, `ar`), `gdb`, `valgrind`, `strace`, and `man-pages` exist **only inside the flake devShell** (`flake.nix`), not in the global system `PATH`.

- **Every shell command** that invokes build, assembly, disassembly, debugging, or manual tools **MUST** be wrapped in `nix develop --command`:
  ```bash
  nix develop --command bash -c "<your command>"
  ```
- Note: `flake.nix` sets `hardeningDisable = [ "all" ];` so Nix's default GCC hardening wrappers do not interfere with low-level assembly linking and tests.

---

## 3. 42 `libasm` Technical Specifications & Constraints

### General Requirements
- **Library Name**: `libasm.a` (archived with `ar rcs`).
- **Assembler & Syntax**: `nasm -f elf64` (64-bit ELF, Intel syntax).
- **Forbidden**: Inline assembly (`asm()` / `__asm__`) in C files, AT&T syntax, or compiling `.c` implementations into `libasm.a`.
- **Makefile Rules**: `all`, `$(NAME)`, `clean`, `fclean`, `re`, `bonus`, `test`.
- **Non-Executable Stack**: Include `section .note.GNU-stack noalloc noexec nowrite progbits` at the end of `.s` files (or pass `-Wl,-z,noexecstack` when linking tests) to prevent GNU `ld` executable-stack warnings.

### Mandatory Functions
1. `size_t ft_strlen(const char *s);` (`man 3 strlen`)
2. `char *ft_strcpy(char *dst, const char *src);` (`man 3 strcpy`)
3. `int ft_strcmp(const char *s1, const char *s2);` (`man 3 strcmp` — **must** compare bytes as `unsigned char` via `movzx`)
4. `ssize_t ft_write(int fd, const void *buf, size_t count);` (`man 2 write`, syscall `1`)
5. `ssize_t ft_read(int fd, void *buf, size_t count);` (`man 2 read`, syscall `0`)
6. `char *ft_strdup(const char *s);` (`man 3 strdup`, calls `malloc`)
7. `void *ft_calloc(size_t nmemb, size_t size);` (`man 3 calloc`, calls `malloc`; **must** detect `size_t` multiplication overflow in `nmemb * size` using unsigned `mul` + `jc`/`jo` before calling `malloc`, set `errno = ENOMEM` on failure, and zero-initialize the allocated memory)

### Bonus Functions (`*_bonus.s`)
```c
typedef struct s_list {
    void          *data; // offset 0  (8 bytes)
    struct s_list *next; // offset 8  (8 bytes)
} t_list;                // sizeof = 16 bytes
```
1. `int ft_atoi_base(char *str, char *base);`
2. `void ft_list_push_front(t_list **begin_list, void *data);`
3. `int ft_list_size(t_list *begin_list);`
4. `void ft_list_sort(t_list **begin_list, int (*cmp)());`
5. `void ft_list_remove_if(t_list **begin_list, void *data_ref, int (*cmp)(), void (*free_fct)(void *));`
6. `void *ft_simd_memchr(const void *s, int c, size_t n);` (SSE2 / AVX2 vectorized scan)

---

## 4. System V AMD64 ABI & Linux Syscall Checklist

Always verify these invariants when reviewing or debugging `.s` files:

| Category | Rule |
| :--- | :--- |
| **Integer Args** | `1st: rdi`, `2nd: rsi`, `3rd: rdx`, `4th: rcx`, `5th: r8`, `6th: r9` |
| **Return Value** | `rax` (64-bit / pointer / `ssize_t`), `eax` (32-bit `int` for `ft_strcmp`, `ft_atoi_base`, `ft_list_size` — sign-extended or zero-extended properly) |
| **Caller-Saved (Volatile)** | `rax`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`–`r11`, `xmm0`–`xmm15`, `eflags` (may be clobbered freely; **not** preserved across `call`) |
| **Callee-Saved (Non-Volatile)** | `rbx`, `rbp`, `r12`–`r15`, `rsp` (**MUST** be saved and restored before `ret` if modified) |
| **Stack Alignment** | `rsp` **MUST** be 16-byte aligned (`rsp % 16 == 0`) immediately **before** any `call` instruction. Upon function entry, `call` pushed an 8-byte return address (`rsp % 16 == 8`), so push an odd number of 64-bit registers (e.g., `push rbp` or `push rbx`) or `sub rsp, 8` before calling `malloc`, `free`, `__errno_location`, `cmp`, or `free_fct`. |
| **Direction Flag (`DF`)** | Must be clear (`cld`, `DF = 0`) on function entry and exit if using string instructions (`rep movsb`, `rep stosb`). |
| **PIC / PLT Calls** | On x86-64 Linux ELF64, call external functions via PLT: `call malloc wrt ..plt`, `call __errno_location wrt ..plt`, `call free wrt ..plt`. |
| **Linux `syscall` Error Handling** | `syscall` clobbers `rcx` and `r11`. On error, Linux returns `-errno` in `rax` (`rax < 0`, specifically `-4095 <= rax < 0`). Negate `rax` (`neg rax`), save the 32-bit error value, call `__errno_location wrt ..plt` (which returns `int *` in `rax`), write the 32-bit `int` error (`mov [rax], edi`), and return `-1` (`mov rax, -1`). |

---

## 5. Skills & Specialized Subagents (Preferred Over External MCP)

We keep MCP minimal (no external network MCP servers) and rely on local workspace skills in `.agents/skills/` and specialized subagents.

### Workspace Skills
- **`nasm-syscall-coach`** (`.agents/skills/nasm-syscall-coach/SKILL.md`): x86-64 NASM reference, System V ABI cheat sheet, syscall numbers, `errno` handling, `t_list` layout, and SIMD guide.
- **`disasm-inspector`** (`.agents/skills/disasm-inspector/SKILL.md`): Assembles `.s` files and runs `objdump -d -M intel`, `nm`, `readelf -r`, and automated ABI/stack-alignment checks via `.agents/skills/disasm-inspector/scripts/inspect_asm.sh`.
- **`libasm-tester`** (`.agents/skills/libasm-tester/SKILL.md`): Differential test runner against glibc (`strlen`, `strcpy`, `strcmp`, `write`, `read`, `strdup`, `calloc`, bonus), `valgrind`, and `strace` via `.agents/skills/libasm-tester/scripts/run_checks.sh`.
- **`gdb-asm-debugger`** (`.agents/skills/gdb-asm-debugger/SKILL.md`): Batch GDB instruction tracer (`gdb -batch`) that dumps registers and flags step-by-step via `.agents/skills/gdb-asm-debugger/scripts/gdb_trace.sh`.

### Specialized Subagents (`define_subagent` / `invoke_subagent`)
When delegating analysis, testing, or coaching tasks, define (if not yet defined in the current conversation) and invoke these subagents:
1. **`nasm-syscall-coach`** (Read-only): Explains instructions, flags, ABI rules, and reviews `.s` code without giving away full implementations.
2. **`disasm-abi-inspector`** (Write/Command enabled): Runs `.agents/skills/disasm-inspector/scripts/inspect_asm.sh <file.s>` inside `nix develop` to check disassembly, relocations, and ABI compliance.
3. **`libasm-test-runner`** (Write/Command enabled): Runs `.agents/skills/libasm-tester/scripts/run_checks.sh` and `.agents/skills/gdb-asm-debugger/scripts/gdb_trace.sh` inside `nix develop` to verify behavior against glibc, `valgrind`, and `strace`.
