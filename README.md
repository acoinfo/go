# Go for SylixOS — CGO Support Branch

> **Branch**: `sylixos-cgo` | **Base**: go1.25.0 (`sylixos-patch_on_go1.25`)
> **Status**: ✅ Verified on RK3568 ADP, SylixOS 3.9.0
> **Upstream**: https://github.com/acoinfo/go

---

## Overview

Enables CGO cross-compilation (Go calling C) targeting SylixOS ARM64.
8 source files modified, 175 lines added. All fixes in Go source — **no toolchain changes required**.

## Modified Files

| File | Problem | Fix |
|------|---------|-----|
| `src/cmd/link/internal/ld/data.go` | BFD ld double-addend causes type pointers to point wrong addresses → SIGKILL | Zero embedded pointer data, let RELA addend handle offset alone |
| `src/runtime/proc.go` | `lockOSThread()` + single-M = scheduler deadlock when main goroutine parks | Skip lock/unlockOSThread on SylixOS |
| `src/runtime/sys_sylixos2.go` | SylixOS console needs CRLF, Go outputs LF only → output squashed into one line | Auto-convert trailing LF→CRLF in `write1` for stdout/stderr |
| `src/runtime/chan.go` | External linker corrupts `chan` type metadata → `makechan` throw | Detect and repair corrupted Size_/Align_ at runtime |
| `src/runtime/symtab.go` | Linker corrupts ftab sentinel, string tables, typelinks base | Runtime repair: ftab, loadBias (0x40000000000), typelinks/etypes |
| `src/runtime/type.go` | Corrupted GCData pointer → GC scan dereferences invalid address → SIGKILL | Detect invalid GCData/PtrBytes, rebuild GC mask at runtime |
| `src/cmd/go/internal/work/exec.go` | SylixOS has no `-pthread` | Skip pthread flag |
| `src/os/user/lookup_sylixos.go` | CGO + os/user = circular dependency | Add `!cgo` build tag |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/kose0922/go.git -b sylixos-cgo
cd go

# 2. Edit build_sylixos_cgo.sh — set paths for your environment
#    (GOROOT_BOOTSTRAP, SYLIXOS_SDK, SYLIXOS_GCC)

# 3. One-click build
./build_sylixos_cgo.sh
```

## Manual Build

### Prerequisites
- Bootstrap Go 1.24+ (any platform)
- `aarch64-sylixos-elf-gcc` 10.2.1 (RealEvo toolchain)
- SylixOS SDK (libsylixos, libcextern)

### Steps

```bash
# A. Build Go compiler
cd src
export GOROOT_BOOTSTRAP="/path/to/bootstrap/go"
export CGO_CFLAGS="-I$SDK/libsylixos/SylixOS -I$SDK/libsylixos/SylixOS/include -fno-exceptions -fPIC"
./make.bash        # Linux/Mac: make.bash | Windows: make.bat

# B. Build C stub library
cd ../cgo-test
aarch64-sylixos-elf-gcc -shared -fPIC -o libgolib.so golib.c \
    -I$SDK/libsylixos/SylixOS -I$SDK/libsylixos/SylixOS/include

# C. Cross-compile
export GOOS="sylixos" GOARCH="arm64" CGO_ENABLED="1"
export CC="/path/to/aarch64-sylixos-elf-gcc"
export CGO_LDFLAGS="-shared -L$SDK/libsylixos/Release -L$SDK/libcextern/Release -L. -lcextern -lgolib"
../bin/go build -a -ldflags="-linkmode=external" -o myapp main_nc.go

# D. Deploy (FTP → ADP)
# Upload myapp + libgolib.so to /apps/, then telnet → ./myapp
```

> **Note**: Modifying `src/runtime/*.go` does NOT require `make.bash`. Use `go build -a`. Only `src/cmd/link/*` changes need Step A.

## Repository Structure

```
├── build_sylixos_cgo.sh     # One-click build script
├── README.md
├── src/                     # Full Go source (this branch == upstream + 8 modified files)
├── cgo-test/
│   ├── main_nc.go           # CGO test program
│   ├── golib.c              # C stub
│   ├── build.sh             # Test-only build
│   └── linker_analysis/     # ELF relocation analysis tools (Python)
```

## Known Limitations

- **Single-M only**: SylixOS Go runs on a single OS thread. CGO calls from multiple goroutines serialize on the C stack.
- **External linker required**: `-ldflags="-linkmode=external"` is mandatory.
- **Pre-built binary** (`cgo-test/main_nc_v17`) is for RK3568 only; rebuild for other boards.

## Verification

```
=== SylixOS CGO Verification ===
C.add( 3 , 5 ) = 8
C.factorial( 7 ) = 5040
Hello from Go->C!
Go var x = 42 at addr 0x...
=== ALL CGO TESTS PASSED ===
```
