#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ft_func.s>"
  exit 1
fi

TARGET="$1"

nix develop --command bash -c '
  set -euo pipefail
  TARGET="'"$TARGET"'"
  FUNC_NAME="$(basename "$TARGET" .s)"
  TMP_DIR="$(mktemp -d /tmp/libasm_abi_XXXXXX)"
  trap "rm -rf \"$TMP_DIR\"" EXIT

  nasm -f elf64 -Wall "$TARGET" -o "$TMP_DIR/$FUNC_NAME.o"

  cat > "$TMP_DIR/canary.s" <<EOF
section .text
global abi_call_wrapper

; uint64_t abi_call_wrapper(void *fn, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, int *clobbered_out)
; System V args:
;   rdi = fn
;   rsi = a1
;   rdx = a2
;   rcx = a3
;   r8  = a4
;   r9  = clobbered_out
abi_call_wrapper:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r9                 ; save clobbered_out pointer (7 pushes -> rsp % 16 == 0!)

    mov rax, rdi            ; fn pointer
    mov rdi, rsi            ; arg1
    mov rsi, rdx            ; arg2
    mov rdx, rcx            ; arg3
    mov rcx, r8             ; arg4

    ; Load canary values into callee-saved registers
    mov rbx, 0x1111222233334444
    mov rbp, 0x2222333344445555
    mov r12, 0x3333444455556666
    mov r13, 0x4444555566667777
    mov r14, 0x5555666677778888
    mov r15, 0x6666777788889999

    call rax

    mov r10, 0              ; bitmask of clobbered registers
    mov r11, 0x1111222233334444
    cmp rbx, r11
    je .chk_rbp
    or r10, 1
.chk_rbp:
    mov r11, 0x2222333344445555
    cmp rbp, r11
    je .chk_r12
    or r10, 2
.chk_r12:
    mov r11, 0x3333444455556666
    cmp r12, r11
    je .chk_r13
    or r10, 4
.chk_r13:
    mov r11, 0x4444555566667777
    cmp r13, r11
    je .chk_r14
    or r10, 8
.chk_r14:
    mov r11, 0x5555666677778888
    cmp r14, r11
    je .chk_r15
    or r10, 16
.chk_r15:
    mov r11, 0x6666777788889999
    cmp r15, r11
    je .done_chk
    or r10, 32
.done_chk:
    pop r9
    mov [r9], r10d

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
EOF

  nasm -f elf64 "$TMP_DIR/canary.s" -o "$TMP_DIR/canary.o"

  cat > "$TMP_DIR/driver.c" <<EOF
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern uint64_t abi_call_wrapper(void *fn, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, int *clobbered);
extern void $FUNC_NAME(void);

int main(void) {
    char buf1[32] = "hello 42";
    char buf2[32] = "hello 42";
    int clobbered = 0;

    abi_call_wrapper((void *)$FUNC_NAME, (uint64_t)buf1, (uint64_t)buf2, 0, 0, &clobbered);
    if (clobbered == 0) {
        printf("[PASS] %s preserved all callee-saved registers (rbx, rbp, r12-r15) and rsp!\n", "$FUNC_NAME");
        return 0;
    } else {
        printf("[FAIL] %s clobbered callee-saved registers! Mask=0x%x (1=rbx,2=rbp,4=r12,8=r13,16=r14,32=r15)\n", "$FUNC_NAME", clobbered);
        return 1;
    }
}
EOF

  cc -Wall -Wextra -Werror "$TMP_DIR/driver.c" "$TMP_DIR/canary.o" "$TMP_DIR/$FUNC_NAME.o" -Wl,-z,noexecstack -o "$TMP_DIR/abi_test"
  "$TMP_DIR/abi_test"
'
