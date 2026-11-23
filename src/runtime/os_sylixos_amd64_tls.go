// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && amd64

package runtime

// osSetupTLS is a no-op on sylixos/amd64. needm calls it unconditionally,
// so an implementation must exist for every sylixos architecture. The
// TP==0 fallback in os_sylixos_cgo_tls.go is arm64-only; amd64 keeps the
// pre-existing behavior of relying on the loader-installed thread pointer.
func osSetupTLS(mp *m) {
}
