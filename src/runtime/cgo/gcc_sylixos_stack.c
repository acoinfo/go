// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// SylixOS stack-bound query.
//
// SylixOS does not expose pthread_getattr_np, so the generic unix
// implementation (gcc_stack_unix.c) falls back to returning zero bounds,
// which leaves the callback g0 stack at the 32KB cgocallbackg estimate.
// The cgo callback machinery (panic unwinding etc.) needs more headroom,
// so return a generous window around the current SP. Threads created by
// _cgo_sys_thread_start use a 1MB stack, so a 1MB window below SP is
// conservative for them and for the main thread.

#include <stdint.h>
#include "libcgo.h"

void
x_cgo_getstackbound(uintptr bounds[2])
{
	uintptr sp = (uintptr)__builtin_frame_address(0);
	bounds[0] = sp - 1 * 1024 * 1024;
	bounds[1] = sp + 1 * 1024 * 1024;
}
