---
name: gdb-asm-debugger
description: >-
  Use this skill when debugging segfaults, infinite loops, register clobbering,
  flags (ZF, CF, SF, OF), or stack alignment issues in assembly functions using
  batch GDB inside nix develop.
---

# Batch GDB Assembly Debugger

Use this skill to trace execution instruction-by-instruction and inspect registers, flags (`eflags`), and stack alignment (`rsp`) non-interactively via `gdb -batch` inside `nix develop`.

## Quick Trace Script

Run [scripts/gdb_trace.sh](./scripts/gdb_trace.sh) on any binary and function name:

```bash
# Step through up to 30 instructions of ft_strlen in ./test:
.agents/skills/gdb-asm-debugger/scripts/gdb_trace.sh ./test ft_strlen 30
```

## Useful One-Shot GDB Commands (via `nix develop`)

- **Inspect crash / segfault backtrace and registers**:
  ```bash
  nix develop --command gdb -batch \
    -ex "set disassembly-flavor intel" \
    -ex "run" \
    -ex "info registers" \
    -ex "x/5i \$rip" \
    -ex "bt" \
    ./test
  ```
- **Verify 16-byte stack alignment at a `call` instruction**:
  At entry to a function (`break ft_strdup`), `$rsp & 0xf` is `8` (because `call` pushed the 8-byte return address). Right before executing an inner `call malloc`, `$rsp & 0xf` **must be `0`**.
