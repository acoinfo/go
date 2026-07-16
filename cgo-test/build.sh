# SylixOS CGO Build & Deploy Script
# This script cross-compiles a cgo Go program for SylixOS and deploys to ADP

set -e

# Configuration
GOOS=sylixos
GOARCH=arm64
ADP_HOST=10.13.42.87
ADP_PORT=23
ADP_USER=root
ADP_PASS=root
APP_NAME=main

# SylixOS GCC toolchain (adjust path as needed)
SYLIXOS_GCC=/opt/sylixos-toolchain/bin/aarch64-sylixos-gcc

echo "=== Building cgo test for SylixOS ==="
echo "GOOS=$GOOS GOARCH=$GOARCH"

# Build using external linker (cgo mode)
CGO_ENABLED=1 \
GOOS=$GOOS \
GOARCH=$GOARCH \
go build -o $APP_NAME main.go

echo "=== Build complete: $APP_NAME ==="
ls -la $APP_NAME

echo "=== Deploying to ADP ($ADP_HOST) ==="
echo "To deploy manually:"
echo "  1. Connect: telnet $ADP_HOST"
echo "  2. Upload $APP_NAME to /apps/"
echo "  3. Run: ./$APP_NAME"
