// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm

package runtime

// SylixOS does not expose AT_HWCAP, so there is nothing to verify here.
func checkgoarm() {}

// osSetupTLS installs a per-thread TLS area for a C thread entering Go.
// SylixOS installs TPIDRURO for every thread of a process that has a TLS
// segment, and a Go binary always has one (runtime.tls_g in .tbss, see
// tls_arm.s), so cgo threads already have a valid thread pointer and
// there is nothing to install.
func osSetupTLS(mp *m) {}
