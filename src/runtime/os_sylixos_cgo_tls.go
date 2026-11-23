// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm64

package runtime

import "unsafe"

// getTLSBase / setTLSBase read and write the thread pointer (TPIDR_EL0).
// SylixOS only installs TPIDR_EL0 for threads of a process with a TLS
// segment (VP_stTlsSize > 0); a c-shared library dlopen'd into a plain C
// process runs with TPIDR_EL0 == 0, so needm and the c-shared bootstrap
// must install the m's own TLS area before save_g can persist g.
//
//go:nosplit
func getTLSBase() uintptr

//go:nosplit
func setTLSBase(uintptr)

// osSetupTLS is called by needm for a C thread entering Go. On SylixOS it
// installs a per-thread TLS area when the loader left TPIDR_EL0 == 0.
//
// Known limitations of this fallback (a process with no TLS segment,
// TPIDR_EL0 == 0; not hit by the tested deployments, which always have a TLS
// segment — see the 2026-08-19 code review notes):
//   - The pointer is only installed when TPIDR_EL0 == 0, so if the thread is
//     served a different extra M on a later needm (getExtraM/dropm reuse M's
//     across threads), TPIDR_EL0 still points at the first M's tls array and
//     save_g writes g into the wrong (stale) M — cross-thread g corruption.
//   - save_g/load_g store g at TPIDR_EL0 + runtime.tls_g. The fallback points
//     at &mp.tls, so tls_g must stay within m.tls (len(m.tls) words); with an
//     external linker a tls_g >= len(m.tls)*8 would overwrite adjacent m
//     fields. Neither case is validated at runtime.
//
//go:nosplit
func osSetupTLS(mp *m) {
	if getTLSBase() == 0 {
		setTLSBase(uintptr(unsafe.Pointer(&mp.tls)))
	}
}
