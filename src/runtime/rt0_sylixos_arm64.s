// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm64

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"
#include "tls_arm64.h"
#include "cgo/abi_arm64.h"

TEXT _rt0_arm64_sylixos(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·rt0_go(SB), R3
	BL	(R3)
	MOVW	$-1, R0
	CALL	libc_exit(SB)

TEXT main(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·rt0_go(SB), R3
	BL	(R3)
	MOVW	$-1, R0
	CALL	libc_exit(SB)

// _rt0_arm64_sylixos_lib is the entry point for libraries built with
// -buildmode=c-shared (and c-archive). The SylixOS loader runs the module's
// .init_array functions at dlopen (loader.c initArrayCall) and the Go linker
// places this symbol there (cmd/link ld/symtab.go addinitarrdata) whenever it
// is defined. Without it the Go runtime is never bootstrapped for a dlopen'd
// library and the first call into an exported function hangs in needm.
//
// SylixOS-specific differences from rt0_linux_arm64.s:
//   - The runtime init thread is created via _cgo_sys_thread_create, exactly
//     like rt0_linux_arm64.s. The synchronous part of the entry runs on the
//     dlopen thread with g == 0, so thread creation must be done from C: Go
//     code faults on its stack-guard check (reads g.stackguard0) when g == 0.
//     newosproc0 remains only for the never-taken no-cgo fallback.
//   - rt0_go reads the environment from R2 (SylixOS). A dlopen'd library has
//     no process argc/argv/env on its thread stack, so _rt0_arm64_sylixos_lib_go
//     installs an empty environment vector (sysargs is a no-op on SylixOS and
//     goenvs reads the env saved here by sylixosenvs).
TEXT _rt0_arm64_sylixos_lib(SB),NOSPLIT,$184
	// Preserve callee-save registers.
	SAVE_R19_TO_R28(24)
	SAVE_F8_TO_F15(104)

	// Initialize g as null in case of using g later e.g. sigaction in cgo_sigaction.go
	MOVD	ZR, g

	// Synchronous initialization.
	MOVD	$runtime·libpreinit(SB), R4
	BL	(R4)

	// Create a new thread to do the runtime initialization and return.
	// The synchronous part of a shared-library entry runs on the dlopen
	// thread with no g (g == 0 set above), so the thread MUST be created
	// from C (_cgo_sys_thread_create). Calling Go here (newosproc0 ->
	// retryOnEAGAIN) hits the Go stack-guard check, which dereferences g
	// and SIGSEGVs (addr=0x10) with g == 0. Mirrors rt0_linux_arm64.s.
	MOVD	_cgo_sys_thread_create(SB), R4
	CBZ	R4, nocgo
	MOVD	$_rt0_arm64_sylixos_lib_go(SB), R0
	MOVD	$0, R1
	SUB	$16, RSP		// reserve 16 bytes for sp-8 where fp may be saved.
	BL	(R4)
	ADD	$16, RSP
	B	restore

nocgo:
	// No cgo: fall back to the runtime thread primitive. Never taken for
	// SylixOS cgo builds, but kept to mirror rt0_linux_arm64.s.
	MOVD	$0x800000, R0                     // stacksize = 8192KB
	MOVD	$_rt0_arm64_sylixos_lib_go(SB), R1
	MOVD	R0, 8(RSP)
	MOVD	R1, 16(RSP)
	MOVD	$runtime·newosproc0(SB), R4
	BL	(R4)

restore:
	// Restore callee-save registers.
	RESTORE_R19_TO_R28(24)
	RESTORE_F8_TO_F15(104)
	RET

TEXT _rt0_arm64_sylixos_lib_go(SB),NOSPLIT,$0
	// rt0_go reads argc (R0), argv (R1) and, on SylixOS, env (R2).
	// Establish the thread pointer before rt0_go's first save_g: SylixOS
	// only installs TPIDR_EL0 for threads of a process with a TLS segment,
	// and the runtime init thread of a dlopen'd library runs with
	// TPIDR_EL0 == 0. Point it at m0's TLS area so g0 can be saved and
	// later reloaded.
	MRS_TPIDR_R0
	CBNZ	R0, have_tls
	MOVD	$runtime·m0+m_tls(SB), R0
	MSR_TPIDR_R0
have_tls:
	MOVD	$0, R0                            // argc
	MOVD	$0, R1                            // argv
	MOVD	$empty_env<>(SB), R2              // env
	MOVD	$runtime·rt0_go(SB), R4
	B	(R4)

// empty_env is a NULL-terminated environment vector (single NULL entry).
DATA empty_env<>(SB)/8, $0
GLOBL empty_env<>(SB),RODATA,$8
