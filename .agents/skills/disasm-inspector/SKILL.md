---
name: disasm-inspector
description: >-
  Use this skill when assembling .s files, inspecting ELF64 object files (.o) or libasm.a,
  checking Intel-syntax disassembly (objdump -d -M intel), symbol visibility (nm),
  PLT relocations (readelf -r), non-executable stack notes, or auditing System V AMD64 ABI compliance.
---

# Disassembly & ELF64 ABI Inspector

Use this skill to assemble individual `.s` files or `libasm.a` inside the `nix develop` environment and inspect the generated machine code, symbols, relocations, and ABI invariants.

## Quick Inspection Script

Run the bundled helper script on any `.s` or `.o` file:

```bash
.agents/skills/disasm-inspector/scripts/inspect_asm.sh ft_strlen.s
```

What [scripts/inspect_asm.sh](./scripts/inspect_asm.sh) checks automatically inside `nix develop`:
1. **NASM Assembly (`nasm -f elf64 -Wall`)**: Reports any syntax or operand errors with exact line numbers.
2. **Disassembly (`objdump -d -M intel`)**: Displays exact machine bytes and Intel-syntax instructions.
3. **Symbol Table (`nm`)**: Verifies `T` (global text symbol) vs `t` (local) and `U` (undefined external symbols like `malloc`, `__errno_location`).
4. **Relocations (`readelf -r`)**: Verifies external function calls use `R_X86_64_PLT32` (`wrt ..plt`).
5. **GNU Stack Note (`readelf -SW`)**: Checks whether `.note.GNU-stack` is present to avoid executable-stack linker warnings.
6. **Callee-Saved Register & `call` Audit**: Flags uses of `rbx`, `rbp`, `r12`–`r15` and `call` instructions so you can verify `push`/`pop` pairs and 16-byte `rsp` alignment.

## Manual Inspection Commands (via `nix develop`)

- Inspect entire `libasm.a`:
  ```bash
  nix develop --command bash -c "objdump -d -M intel libasm.a && nm -s libasm.a"
  ```
- Assemble with debug symbols (`-g -F dwarf`) for GDB:
  ```bash
  nix develop --command bash -c "nasm -f elf64 -g -F dwarf ft_strlen.s -o ft_strlen.o"
  ```
