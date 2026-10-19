---
name: libasm-tester
description: >-
  Use this skill when building libasm.a, running unit or differential tests against glibc,
  checking memory leaks or invalid accesses with valgrind, or verifying syscall and errno
  behavior with strace inside nix develop.
---

# 42 `libasm` Test, Valgrind & Strace Runner

Use this skill to compile `libasm.a` (or individual `.s` files that are ready to test) and verify them against standard C library (`glibc`) reference behavior, `valgrind`, and `strace`.

## Quick Verification Script

Run [scripts/run_checks.sh](./scripts/run_checks.sh) to test either a single function (even before all 7 mandatory `.s` files exist!) or the full `libasm.a` library:

```bash
# Test a single .s file in isolation against glibc + valgrind:
.agents/skills/libasm-tester/scripts/run_checks.sh single ft_strlen.s

# Run make test (full libasm.a + main.c + valgrind):
.agents/skills/libasm-tester/scripts/run_checks.sh all

# Run strace on ./test to inspect raw read/write syscalls and errno:
.agents/skills/libasm-tester/scripts/run_checks.sh strace
```

## Differential Test Coverage Checklist

When writing or expanding tests in `main.c` (or temporary harnesses), always compare `ft_<func>` vs `<func>` on:

1. **`ft_strlen`**:
   - `""` (empty string -> `0`)
   - `"a"` (`1`), `"hello\0hidden"` (`5`), 4096-byte string
2. **`ft_strcpy`**:
   - `""`, `"hello"`, buffer with pre-existing non-zero garbage bytes to verify null-terminator copy, return pointer `== dst`
3. **`ft_strcmp`**:
   - Equal strings (`""` vs `""`, `"abc"` vs `"abc"`)
   - Prefix strings (`"abc"` vs `"abcd"`, `"abcd"` vs `"abc"`)
   - **Unsigned char edge case**: `"\xff"` vs `"\x01"` (must return `> 0`, because `(unsigned char)'\xff' == 255 > 1`!)
4. **`ft_write` & `ft_read`**:
   - Normal pipe / temp file / stdout / stdin read & write (`count = 0`, `count = 1`, large buffer)
   - Error cases with `errno` reset (`errno = 0` before call):
     - `fd = -1` -> returns `-1`, `errno == EBADF` (`9`)
     - `buf = NULL` with `count > 0` on valid `fd` -> returns `-1`, `errno == EFAULT` (`14`)
5. **`ft_strdup`**:
   - `""`, `"42 Tokyo"`, long string; verify returned pointer is distinct from `src` and `free()` succeeds with zero leaks under `valgrind`
6. **`ft_calloc`**:
   - `(0, 0)`, `(10, sizeof(int))` -> verify all bytes are `0` (test by allocating/freeing dirty heap memory first)
   - **Overflow detection**: `(SIZE_MAX, 2)` and `(1ULL << 33, 1ULL << 33)` -> must return `NULL` and set `errno == ENOMEM` (`12`) without wrapping around in `nmemb * size`!
