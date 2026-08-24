// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// SylixOS/arm64 cgo OS layer.
//
// Previously these two symbols lived in an external libgolib.so; shipping a
// stub there made every cgo program silently depend on the deployed library
// matching the build. Putting them here links them into every cgo binary so
// the runtime is self-contained (the same model as gcc_linux_arm64.c).
//
// SylixOS specifics:
//   - pthread_attr_setstack rejects Go-allocated g0 stacks (EINVAL), so we
//     let pthread provide the physical stack and leave stacklo=0 +
//     stackhi=size. mstart0 (proc.go) detects lo==0 and recomputes the g0
//     stack bounds from SP.
//   - The main g0's stack is set up by rt0_go (asm_arm64.s) before x_cgo_init
//     runs, and the platform TLS (TPIDR_EL0) holds g, so x_cgo_init only needs
//     to remember the setg callback for threadentry.

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

// setg callback saved by x_cgo_init (setg_gcc<> in asm_arm64.s).
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

	// Same as mstart_stub: bind g0 (register + TLS), then enter Go.
	crosscall1(ts.fn, setg_gcc, (void *)ts.g);
	return NULL;
}

void
x_cgo_init(G *g, void (*setg)(void *), void **tlsg, void **tlsbase)
{
	uintptr *pbounds;

	// SylixOS/arm64 uses the platform TLS (TPIDR_EL0), so rt0_go passes
	// tlsg/tlsbase as NULL and the main thread's g is saved by rt0_go right
	// after this call (BL runtime.save_g). We keep the setg callback for
	// threadentry, and we correct the main g0 stack bounds: rt0_go starts
	// with a 64KB estimate which is too small for cgo C frames (e.g. the
	// 64KB test callback) plus panic unwinding.
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
