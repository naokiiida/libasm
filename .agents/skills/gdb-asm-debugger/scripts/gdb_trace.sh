#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <binary> <function_name> [max_steps]"
  echo "Example: $0 ./test ft_strlen 25"
  exit 1
fi

BIN="$1"
FUNC="$2"
STEPS="${3:-25}"

nix develop --command bash -c '
  set -euo pipefail
  GDB_CMD_FILE="$(mktemp /tmp/gdb_trace_XXXXXX.gdb)"
  trap "rm -f \"$GDB_CMD_FILE\"" EXIT

  cat > "$GDB_CMD_FILE" <<EOF
set pagination off
set disassembly-flavor intel
break '"$FUNC"'
run
printf "=== Entered '"$FUNC"' (rsp=0x%lx, rsp%%16=%lu) ===\n", \$rsp, ((unsigned long)\$rsp & 0xf)
set \$step_count = 0
while (\$step_count < '"$STEPS"')
  x/1i \$rip
  printf "  rax=0x%lx rdi=0x%lx rsi=0x%lx rdx=0x%lx rcx=0x%lx rsp=0x%lx (rsp%%16=%lu)\n", \$rax, \$rdi, \$rsi, \$rdx, \$rcx, \$rsp, ((unsigned long)\$rsp & 0xf)
  info registers eflags
  stepi
  set \$step_count = \$step_count + 1
end
quit
EOF

  gdb -batch -x "$GDB_CMD_FILE" "'"$BIN"'"
'
