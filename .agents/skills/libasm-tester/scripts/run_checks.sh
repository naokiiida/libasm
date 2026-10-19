#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-wip}"
TARGET="${2:-all}"

nix develop --command bash -c '
  set -euo pipefail
  MODE="'"$MODE"'"
  TARGET="'"$TARGET"'"

  if [[ "$MODE" == "single" ]]; then
    if [[ "$TARGET" == "all" || -z "$TARGET" ]]; then
      echo "Usage: $0 single <ft_func.s>"
      exit 1
    fi
    FUNC_NAME="$(basename "$TARGET" .s)"
    SHORT_NAME="${FUNC_NAME#ft_}"
    SHORT_NAME="${SHORT_NAME%_bonus}"
    TMP_DIR="$(mktemp -d /tmp/libasm_test_XXXXXX)"
    trap "rm -rf \"$TMP_DIR\"" EXIT

    echo "=== [1/3] Assembling $TARGET (nasm -f elf64 -g -F dwarf -Wall) ==="
    nasm -f elf64 -g -F dwarf -Wall "$TARGET" -o "$TMP_DIR/$FUNC_NAME.o"
    ar rcs "$TMP_DIR/libasm.a" "$TMP_DIR/$FUNC_NAME.o"

    echo "=== [2/3] Linking main.c against $FUNC_NAME.o ==="
    cc -Wall -Wextra -Werror -g -I. main.c -Wl,--whole-archive -L"$TMP_DIR" -lasm -Wl,--no-whole-archive -Wl,-z,noexecstack -o "$TMP_DIR/test"

    echo "=== [3/3] Running Test Suite + Valgrind ($SHORT_NAME) ==="
    "$TMP_DIR/test" "$SHORT_NAME"
    LIBASM_UNDER_VALGRIND=1 valgrind -q --leak-check=full --show-leak-kinds=all --error-exitcode=1 "$TMP_DIR/test" "$SHORT_NAME" > /dev/null
    echo "[PASS] Valgrind Memcheck: 0 errors, 0 leaks!"

  elif [[ "$MODE" == "wip" ]]; then
    make test-wip FILTER="$TARGET"

  elif [[ "$MODE" == "strace" ]]; then
    make test-wip FILTER="$TARGET"
    strace -e trace=read,write ./test "$TARGET"

  else
    make test FILTER="$TARGET"
  fi
'
