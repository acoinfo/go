# Go for SylixOS — CGO Support Branch

> **Branch**: `sylixos-cgo` | **Based on**: `sylixos-patch_on_go1.25` (go1.25.0)
> **Status**: ✅ CGO cross-compilation to SylixOS ARM64 fully working
> **Upstream**: https://github.com/acoinfo/go

---

## What This Branch Does

This branch adds **CGO support** to the SylixOS Go port. With these changes, Go programs calling C code can be cross-compiled and run on SylixOS ARM64 (verified on RK3568 ADP, SylixOS 3.9.0).

## Modified Files (8 files, 175 lines added)

| File | Change |
|------|--------|
| `src/cmd/link/internal/ld/data.go` | Zero embedded pointer data for SylixOS ELF — avoids BFD ld double-addend bug (+6) |
| `src/runtime/proc.go` | Skip `lockOSThread`/`unlockOSThread` on SylixOS — prevents single-M deadlock (+10) |
| `src/runtime/sys_sylixos2.go` | Auto LF→CRLF in `write1` for SylixOS console compatibility (+28) |
| `src/runtime/chan.go` | Fix `makechan` corrupted `Size_`/`Align_` from external linker (+27) |
| `src/runtime/symtab.go` | Fix ftab sentinel, loadBias 0x40000000000, typelinks/etypes repair (+60) |
| `src/runtime/type.go` | Detect corrupted GCData/PtrBytes, rebuild GC mask at runtime (+45) |
| `src/cmd/go/internal/work/exec.go` | Skip `-pthread` on SylixOS (+2) |
| `src/os/user/lookup_sylixos.go` | Add `!cgo` build tag (+1) |

All fixes in Go source. **No changes to SylixOS toolchain required.**

## Two Core Problems Solved

### 1. BFD ld Double-Addend → SIGKILL
SylixOS BFD ld applies `R_AARCH64_ABS64` as `S + addend + *(data)` instead of standard `S + addend`. Type pointers in `moduledata` point to wrong addresses → crash.

**Fix** (`data.go`): Zero the data field, let RELA addend handle offset alone (same as AMD64).

### 2. Single-M Scheduler Deadlock
`lockOSThread()` locks main goroutine to M0. When it parks in `gcenable()`, `stoplockedm()` tries to create a new M — but SylixOS is single-threaded — M0 sleeps forever.

**Fix** (`proc.go`): Skip lockOSThread/unlockOSThread on SylixOS.

## Build & Deploy

### Prerequisites
- RealEvo-IDE running (GCC license server required)
- Git Bash on Windows
- Bootstrap Go (go1.24.5+ windows/amd64)
- SylixOS GCC: `aarch64-sylixos-elf-gcc` (10.2.1)

### Step A: Build Go Compiler
```bash
cd src
export GOROOT_BOOTSTRAP="/c/Users/taoran/go"
export CGO_CFLAGS="-I<SDK>/libsylixos/SylixOS -I<SDK>/libsylixos/SylixOS/include -fno-exceptions -fPIC"
./make.bat
```
> Only needed when `src/cmd/link/*` is modified. `src/runtime/*` changes don't require rebuild.

### Step B: Build C Stub Library
```bash
cd cgo-test
aarch64-sylixos-elf-gcc -shared -fPIC -o libgolib.so golib.c
```

### Step C: Cross-Compile
```bash
cd cgo-test
export GOOS="sylixos" GOARCH="arm64" CGO_ENABLED="1"
export CC="<path>/aarch64-sylixos-elf-gcc.exe"
export CGO_LDFLAGS="-shared -L<SDK>/libsylixos/Release -L<SDK>/libcextern/Release -L. -lcextern -lvpmpdm -lfastlock -lgolib"
go build -a -ldflags="-linkmode=external" -o main_nc main_nc.go
```

### Step D: Deploy
FTP upload `main_nc` and `libgolib.so` to ADP `/apps/`, then `telnet` → `./main_nc`.

## Verification Output

```
=== SylixOS CGO Verification ===
C.add( 3 , 5 ) = 8
C.factorial( 7 ) = 5040
Hello from Go->C!
Go var x = 42 at addr 4399254765336
=== ALL CGO TESTS PASSED ===
```

## Directory

```
cgo-test/
├── main_nc.go          # CGO test (C.add, C.factorial, C.say)
├── main_nc_v17         # Pre-built ADP binary (RK3568)
├── golib.c / libgolib.so
├── build.sh
└── linker_analysis/    # ELF analysis scripts
```
