// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos

#include "textflag.h"

// Trampolines for the per-architecture 64-bit off_t wrappers. They are
// kept out of zsyscall_sylixos.s because the wrappers and their dynamic
// import declarations are hand-maintained (syscall_sylixos_offt.go).

TEXT ·libc_ftruncate_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_ftruncate(SB)
TEXT ·libc_lseek_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_lseek(SB)
TEXT ·libc_mmap_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_mmap(SB)
TEXT ·libc_pread_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_pread(SB)
TEXT ·libc_pwrite_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_pwrite(SB)
TEXT ·libc_truncate_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_truncate(SB)
