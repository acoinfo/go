#!/bin/bash
# ============================================================
# SylixOS CGO Go Compiler — One-Click Build Script
# ============================================================
# This script builds the Go compiler with SylixOS CGO support
# and cross-compiles the test program.
#
# Prerequisites:
#   1. RealEvo-IDE running (GCC license server)
#   2. Bootstrap Go (go1.24+) at C:\Users\<user>\go
#   3. Git Bash on Windows
#
# Usage:  ./build_sylixos_cgo.sh
# ============================================================

set -e

# ── Paths (edit these to match your environment) ──────────────────
GOROOT_BOOTSTRAP="${GOROOT_BOOTSTRAP:-$HOME/go}"
SYLIXOS_SDK="${SYLIXOS_SDK:-D:/workspace/IGC3503/Base_ecs_64_3503}"
SYLIXOS_GCC="${SYLIXOS_GCC:-D:/RealEvo/compiler/aarch64-sylixos-toolchain/bin/aarch64-sylixos-elf-gcc.exe}"

SYLIXOS_INC="$SYLIXOS_SDK/libsylixos/SylixOS"
SYLIXOS_INC2="$SYLIXOS_SDK/libsylixos/SylixOS/include"
SYLIXOS_INC_NET="$SYLIXOS_SDK/libsylixos/SylixOS/include/network"
SYLIXOS_CEXTERN_INC="$SYLIXOS_SDK/libcextern/libcextern/include"
SYLIXOS_LIB="$SYLIXOS_SDK/libsylixos/Release"
SYLIXOS_CEXTERN_LIB="$SYLIXOS_SDK/libcextern/Release"
GCC_INC="$GCC_INC_PREFIX/lib/gcc/aarch64-sylixos-elf/10.2.1/include-fixed"

GO_SRC="$(cd "$(dirname "$0")" && pwd)"
CGO_TEST="$GO_SRC/cgo-test"

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_step()  { echo -e "${GREEN}[STEP]${NC} $*"; }
echo_ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
echo_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
echo_fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# ── Step 1: Build Go Compiler ─────────────────────────────────────
echo_step "1/3 Building Go compiler for SylixOS CGO..."

export CGO_CFLAGS="-I$SYLIXOS_INC -I$SYLIXOS_INC2 -I$SYLIXOS_INC_NET -I$SYLIXOS_CEXTERN_INC -I$GCC_INC -fno-exceptions -fno-unwind-tables -fPIC"

cd "$GO_SRC/src"
./make.bat 2>&1 | tail -5
echo_ok "Go compiler built"

# ── Step 2: Build C Stub Library ──────────────────────────────────
echo_step "2/3 Building C stub library (libgolib.so)..."

cd "$CGO_TEST"
"$SYLIXOS_GCC" -shared -fPIC -o libgolib.so golib.c \
    -I"$SYLIXOS_INC" -I"$SYLIXOS_INC2" 2>&1

if [ -f libgolib.so ]; then
    echo_ok "libgolib.so built"
else
    echo_fail "libgolib.so build failed"
    exit 1
fi

# ── Step 3: Cross-Compile CGO Test Program ────────────────────────
echo_step "3/3 Cross-compiling CGO test program..."

export GOOS="sylixos"
export GOARCH="arm64"
export CGO_ENABLED="1"
export CC="$SYLIXOS_GCC"
export CGO_LDFLAGS="-v -shared -L$SYLIXOS_LIB -L$SYLIXOS_CEXTERN_LIB -L. -lcextern -lvpmpdm -lfastlock -lgolib"

"$GO_SRC/bin/go" build -a -ldflags="-linkmode=external" -o main_nc_sylixos main_nc.go 2>&1 | tail -3

if [ -f main_nc_sylixos ]; then
    SIZE=$(ls -lh main_nc_sylixos | awk '{print $5}')
    echo_ok "main_nc_sylixos built ($SIZE)"
else
    echo_fail "Cross-compile failed"
    exit 1
fi

# ── Done ───────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Build Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Go compiler:  $GO_SRC/bin/go"
echo "  Test binary:  $CGO_TEST/main_nc_sylixos"
echo ""
echo "  Deploy to ADP:"
echo "    FTP upload $CGO_TEST/main_nc_sylixos → /apps/"
echo "    FTP upload $CGO_TEST/libgolib.so → /apps/"
echo "    telnet → cd /apps → ./main_nc_sylixos"
echo ""
