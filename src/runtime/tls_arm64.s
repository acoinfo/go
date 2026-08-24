// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "funcdata.h"
#include "textflag.h"
#include "tls_arm64.h"

TEXT runtime·load_g(SB),NOSPLIT,$0
#ifndef GOOS_darwin
#ifndef GOOS_openbsd
#ifndef GOOS_windows
#ifndef GOOS_sylixos
	MOVB	runtime·iscgo(SB), R0
	CBZ	R0, nocgo
#endif
#endif
#endif
#endif

	MRS_TPIDR_R0
#ifdef GOOS_sylixos
	// SylixOS only installs TPIDR_EL0 for threads of a process with a TLS
	// segment (VP_stTlsSize > 0). A c-shared library loaded into a plain C
	// process runs with TPIDR_EL0 == 0: report g == 0 so the caller treats
	// the thread as foreign and establishes TLS via needm/osSetupTLS.
	CBZ	R0, zerotls
#endif
#ifdef TLS_darwin
#ifdef GOOS_sylixos
	// Darwin sometimes returns unaligned pointers
	// Maybe Sylixos does it too?
	AND	$0xfffffffffffffff8, R0
#endif
#endif
	MOVD	runtime·tls_g(SB), R27
	MOVD	(R0)(R27), g

#ifdef GOOS_sylixos
	// Do not fall through into zerotls: the TPIDR_EL0 != 0 path already
	// loaded g from TLS above.
	B	nocgo
zerotls:
	MOVD	ZR, g
#endif
nocgo:
	RET

TEXT runtime·save_g(SB),NOSPLIT,$0
#ifndef GOOS_darwin
#ifndef GOOS_openbsd
#ifndef GOOS_windows
#ifndef GOOS_sylixos
	MOVB	runtime·iscgo(SB), R0
	CBZ	R0, nocgo
#endif
#endif
#endif
#endif

	MRS_TPIDR_R0
#ifdef GOOS_sylixos
	// See load_g: with TPIDR_EL0 == 0 there is nowhere to persist g; skip
	// the store. The caller must establish TLS (osSetupTLS / the c-shared
	// lib entry / setg_gcc) before save_g can take effect.
	CBZ	R0, zerotls
#endif
#ifdef TLS_darwin
#ifdef GOOS_sylixos
	// Darwin sometimes returns unaligned pointers
	// Maybe Sylixos does it too?
	AND	$0xfffffffffffffff8, R0
#endif
#endif
	MOVD	runtime·tls_g(SB), R27
	MOVD	g, (R0)(R27)

#ifdef GOOS_sylixos
zerotls:
#endif
nocgo:
	RET

#ifdef TLSG_IS_VARIABLE
#ifdef GOOS_android
// Use the free TLS_SLOT_APP slot #2 on Android Q.
// Earlier androids are set up in gcc_android.c.
DATA runtime·tls_g+0(SB)/8, $16
#endif
GLOBL runtime·tls_g+0(SB), NOPTR, $8
#else
GLOBL runtime·tls_g+0(SB), TLSBSS, $8
#endif
