// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos

package syscall

// Dynamic imports for the system calls that take or return a 64-bit
// off_t. The wrappers are hand-written rather than generated because
// they differ per architecture: arm32 passes a 64-bit value per the ARM
// AAPCS (register pair or 8-byte aligned stack slot), while amd64 and
// arm64 pass it in a single register. The bodies live in
// syscall_sylixos_arm.go and syscall_sylixos_64.go; the assembly
// trampolines live in syscall_sylixos_offt.s.
//
// mksyscall cannot express the per-architecture split, so there must be
// no //sys lines for these names in the mksyscall input files.

func libc_ftruncate_trampoline()

//go:cgo_import_dynamic libc_ftruncate ftruncate "libvpmpdm.so"

func libc_lseek_trampoline()

//go:cgo_import_dynamic libc_lseek lseek "libvpmpdm.so"

func libc_mmap_trampoline()

//go:cgo_import_dynamic libc_mmap mmap64 "libvpmpdm.so"

func libc_pread_trampoline()

//go:cgo_import_dynamic libc_pread pread "libvpmpdm.so"

func libc_pwrite_trampoline()

//go:cgo_import_dynamic libc_pwrite pwrite "libvpmpdm.so"

func libc_truncate_trampoline()

//go:cgo_import_dynamic libc_truncate truncate "libvpmpdm.so"
