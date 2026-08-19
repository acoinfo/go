// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// SylixOS/amd64 cgo OS layer.
//
// Mirrors gcc_sylixos_arm64.c: the two required cgo OS symbols live here so
// every cgo binary is self-contained (the same model as gcc_linux_amd64.c).
//
// SylixOS/amd64 specifics:
//   - g is stored in the platform TLS slot at FS:-8 (same convention as Linux
//     amd64). rt0_go (asm_amd64.s) calls _cgo_init with tlsg/tlsbase = NULL
//     under GOOS_sylixos and skips its own TLS setup, so x_cgo_init only needs
//     to remember the setg_gcc callback for threadentry.
//   - No x_cgo_inittls is needed: the runtime and pthread already agree on the
//     TLS slot, and setg_gcc<> (asm_amd64.s) + crosscall1 (gcc_amd64.S) are the
//     generic amd64 implementations used by every OS.
//   - pthread_attr_setstack rejects Go-allocated g0 stacks (EINVAL), so we let
//     pthread provide the physical stack and leave stacklo=0 + stackhi=size;
//     mstart0 (proc.go) recomputes the g0 stack bounds from SP.

#include <pthread.h>
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include "libcgo.h"
#include "libcgo_unix.h"

// _cgo_set_stacklo is provided by gcc_libinit.c.
void _cgo_set_stacklo(G *, uintptr *);

static void *threadentry(void *v);

// setg callback saved by x_cgo_init (setg_gcc<> in asm_amd64.s).
static void (*setg_gcc)(void *);

void
_cgo_sys_thread_start(ThreadStart *ts)
{
	pthread_attr_t attr;
	sigset_t ign, oset;
	pthread_t p;
	size_t size;
	int err;

	if (ts == NULL || ts->g == NULL || ts->fn == NULL) {
		fatalf("runtime/cgo: bad ThreadStart");
	}

	// Block all signals while creating the thread so the new thread starts
	// with a full signal mask; minit->minitSignals re-enables what is
	// needed later.
	sigfillset(&ign);
	pthread_sigmask(SIG_SETMASK, &ign, &oset);

	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
	// SylixOS pthread_attr_setstack rejects Go-allocated g0 stacks (EINVAL),
	// so follow the Linux cgo convention: let pthread provide the physical
	// stack and leave stacklo=0 + stackhi=size; mstart0 recomputes the g0
	// stack bounds from SP.
	size = 1 << 20; // 1MB: SylixOS default thread stack may be small.
	if (pthread_attr_setstacksize(&attr, size) != 0) {
		pthread_attr_getstacksize(&attr, &size);
	}
	ts->g->stacklo = 0;
	ts->g->stackhi = size;

	err = _cgo_try_pthread_create(&p, &attr, threadentry, ts);

	pthread_sigmask(SIG_SETMASK, &oset, NULL);

	if (err != 0) {
		fatalf("runtime/cgo: pthread_create failed: %s", strerror(err));
	}
}

extern void crosscall1(void (*fn)(void), void (*setg)(void *), void *g);

static void *
threadentry(void *v)
{
	ThreadStart ts;

	// gcc_util.c x_cgo_thread_start malloc'ed a persistent copy.
	ts = *(ThreadStart *)v;
	free(v);

	// Same as mstart_stub: bind g (TLS + R14), then enter Go.
	crosscall1(ts.fn, setg_gcc, (void *)ts.g);
	return NULL;
}

void
x_cgo_init(G *g, void (*setg)(void *), void **tlsg, void **tlsbase)
{
	uintptr *pbounds;

	// SylixOS/amd64 uses the platform TLS (FS:-8), so rt0_go passes
	// tlsg/tlsbase as NULL under GOOS_sylixos and the main thread's g is
	// saved by rt0_go right after this call (CALL runtime.save_g). We keep
	// the setg callback for threadentry, and we correct the main g0 stack
	// bounds: rt0_go starts with a 64KB estimate which is too small for cgo
	// C frames (e.g. the 64KB test callback) plus panic unwinding.
	(void)tlsg;
	(void)tlsbase;
	setg_gcc = setg;

	pbounds = (uintptr *)malloc(2 * sizeof(uintptr));
	if (pbounds == NULL) {
		fatalf("runtime/cgo: malloc failed in x_cgo_init");
	}
	_cgo_set_stacklo(g, pbounds);
	free(pbounds);
}
