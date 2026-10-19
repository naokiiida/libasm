#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file.s | file.o | libasm.a>"
  exit 1
fi

TARGET="$1"

nix develop --command bash -c '
  set -euo pipefail
  TARGET="'"$TARGET"'"
  if [[ "$TARGET" == *.s ]]; then
    TMP_OBJ="$(mktemp /tmp/libasm_inspect_XXXXXX.o)"
    trap "rm -f \"$TMP_OBJ\"" EXIT
    echo "=== [1/5] Assembling $TARGET (nasm -f elf64 -Wall) ==="
    nasm -f elf64 -Wall "$TARGET" -o "$TMP_OBJ"
    echo "OK: Assembled cleanly."
    OBJ="$TMP_OBJ"
  else
    OBJ="$TARGET"
  fi

  echo ""
  echo "=== [2/5] Disassembly (objdump -d -M intel) ==="
  objdump -d -M intel "$OBJ"

  echo ""
  echo "=== [3/5] Symbols (nm) ==="
  nm "$OBJ"

  echo ""
  echo "=== [4/5] Relocations (readelf -r) ==="
  readelf -r "$OBJ"

  echo ""
  echo "=== [5/5] ABI & Section Quick Audit ==="
  if readelf -SW "$OBJ" | grep -q "\.note\.GNU-stack"; then
    echo "[PASS] .note.GNU-stack section present (non-executable stack)."
  else
    echo "[INFO] .note.GNU-stack section not found (consider adding: section .note.GNU-stack noalloc noexec nowrite progbits)."
  fi

  echo "--- Callee-saved registers & calls touched in disassembly ---"
  objdump -d -M intel "$OBJ" | grep -E "\b(rbx|ebx|bx|bl|rbp|ebp|bp|bpl|r12|r13|r14|r15|rsp|esp|call|ret|syscall)\b" || true
'
