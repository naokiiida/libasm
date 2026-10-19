{
  description = "42 libasm dev shell (x86-64 Linux, nasm, Intel syntax)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nasm            # assembler (required by subject)
          gnumake         # Makefile
          gcc             # cc for main.c; links libasm.a
          binutils        # ar, ld, objdump -d -M intel, nm, readelf
          gdb             # debugger (layout asm / regs)
          valgrind        # leak / invalid access check
          strace          # verify syscalls + errno return values
          man-pages       # man 2 write, man 2 syscall, man 7 ...
          man-pages-posix
        ];
        # nixpkgs gcc enables hardening flags that can confuse asm tests
        hardeningDisable = [ "all" ];
        shellHook = ''
          export MANPATH="${pkgs.man-pages}/share/man:${pkgs.man-pages-posix}/share/man:$MANPATH"
          echo "libasm shell: nasm $(nasm -v | cut -d' ' -f3), gcc $(gcc -dumpversion)"
        '';
      };
    };
}
