# x86-64 Instruction Reference for 42 `libasm`

## Data Movement & Extension

### `mov` — Move Data
- **Syntax**: `mov dst, src`
- **Flags**: None modified.
- **Notes**:
  - Cannot move memory-to-memory (`mov [rdi], [rsi]` is invalid).
  - Writing to a 32-bit register (`mov eax, 1`) **zero-extends** the upper 32 bits of the 64-bit register (`rax`).
  - Writing to an 8-bit (`al`) or 16-bit (`ax`) register **leaves upper bits unchanged** (garbage remains!).

### `movzx` — Move with Zero-Extend
- **Syntax**: `movzx dst32/64, src8/16`
- **Examples**:
  - `movzx eax, byte [rdi + rcx]` — loads 1 byte (`0..255`) from memory into `al` and fills bits `8..63` of `rax` with `0`.
  - `movzx eax, al` — zero-extends 8-bit `al` (`0x00..0xff`) into 32-bit `eax` (`0x00000000..0x000000ff`).
- **Flags**: None modified.
- **Why needed in `ft_strcmp`**:
  - `man 3 strcmp` requires characters to be interpreted as `unsigned char` (`0..255`), and the return type is 32-bit signed `int` (`eax`).
  - If `s1[0] = 0xff` (`255`) and `s2[0] = 0x01` (`1`), doing 8-bit `sub al, dl` produces `0xfe` (`-2` in signed 8-bit), and even if zero-extended afterward, `0x01 - 0xff` would wrap around to `0x02` (`+2` instead of `-254`)!
  - By zero-extending **both** bytes into 32-bit registers first (`movzx eax, byte [rdi + rcx]` and `movzx edx, byte [rsi + rcx]`), `sub eax, edx` computes `255 - 1 = +254` and `1 - 255 = -254` in full 32-bit signed arithmetic!

### `movsx` / `movsxd` — Move with Sign-Extend
- **Syntax**: `movsx dst32/64, src8/16` (or `movsxd dst64, src32`)
- **Behavior**: Copies the sign bit (most significant bit of `src`) into all upper bits of `dst`.
- **Flags**: None modified.

### `lea` — Load Effective Address
- **Syntax**: `lea dst64, [base + index*scale + disp]`
- **Behavior**: Computes the address expression inside `[...]` and stores the **number itself** (without dereferencing memory) into `dst64`.
- **Flags**: **None modified** (unlike `add`/`inc`, which clobber flags).

---

## Comparison & Bitwise Tests

### `cmp` — Compare Two Operands
- **Syntax**: `cmp op1, op2`
- **Behavior**: Computes `op1 - op2` and sets CPU flags (`ZF`, `CF`, `SF`, `OF`) **without** storing the result.
  - `op1 == op2` $\rightarrow$ `ZF = 1` (`je` / `jz`)
  - `op1 != op2` $\rightarrow$ `ZF = 0` (`jne` / `jnz`)
  - Unsigned `op1 < op2` $\rightarrow$ `CF = 1` (`jb` / `jc`)
  - Signed `op1 < op2` $\rightarrow$ `SF != OF` (`jl`)
  - Signed `op1 > op2` $\rightarrow$ `ZF == 0 && SF == OF` (`jg`)

### `test` — Logical Compare (Bitwise AND)
- **Syntax**: `test op1, op2`
- **Behavior**: Computes `op1 & op2`, sets `ZF` (`1` if result is `0`) and `SF` (sign bit of result), clears `CF = 0, OF = 0`, and discards the result.
- **Common idiom**:
  - `test rax, rax` + `jz .is_null` (checks if `rax == 0`)
  - `test rax, rax` + `js .is_negative` (checks if `rax < 0`, e.g., after `syscall`)

---

## Arithmetic

### `inc` / `dec` — Increment / Decrement by 1
- **Syntax**: `inc reg/mem`, `dec reg/mem`
- **Flags**: Updates `ZF`, `SF`, `OF` (does **not** touch `CF`).

### `add` / `sub` — Add / Subtract
- **Syntax**: `add dst, src` (`dst = dst + src`), `sub dst, src` (`dst = dst - src`)
- **Flags**: Updates `ZF`, `CF`, `SF`, `OF`.

### `neg` — Two's Complement Negation
- **Syntax**: `neg reg/mem` (`reg = -reg`)
- **Flags**: Sets `CF = 1` (unless operand was `0`), updates `ZF`, `SF`, `OF`.
- **Use in `libasm`**: Converts `-errno` returned by `syscall` in `rax` into positive `errno` (`neg rax`).

### `mul` — Unsigned Multiply
- **Syntax**: `mul reg/mem64`
- **Behavior**: Multiplies unsigned `rax * src64` and stores the 128-bit result in `rdx:rax` (upper 64 bits in `rdx`, lower 64 bits in `rax`).
- **Flags**: Sets **`CF = 1` and `OF = 1`** if the upper half `rdx != 0` (meaning the product overflowed 64 bits!).
- **Use in `ft_calloc`**: `mov rax, rdi` then `mul rsi` then `jc .overflow`.
