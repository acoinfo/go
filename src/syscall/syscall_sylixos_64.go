// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && !arm

package syscall

import (
	"internal/abi"
	"unsafe"
)

// These are the LP64 forms of the wrappers that take or return a 64-bit
// off_t. They live outside the generated zsyscall_sylixos.go so that
// arm32 can provide its own implementations following the ARM AAPCS.

func mmap(addr uintptr, length uintptr, prot int, flag int, fd int, pos int64) (ret uintptr, err error) {
	r0, _, e1 := syscall6X(abi.FuncPCABI0(libc_mmap_trampoline), uintptr(addr), uintptr(length), uintptr(prot), uintptr(flag), uintptr(fd), uintptr(pos))
	ret = uintptr(r0)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}

func Ftruncate(fd int, length int64) (err error) {
	_, _, e1 := syscall(abi.FuncPCABI0(libc_ftruncate_trampoline), uintptr(fd), uintptr(length), 0)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}

func pread(fd int, p []byte, offset int64) (n int, err error) {
	var _p0 unsafe.Pointer
	if len(p) > 0 {
		_p0 = unsafe.Pointer(&p[0])
	} else {
		_p0 = unsafe.Pointer(&_zero)
	}
	r0, _, e1 := syscall6Xerrno(abi.FuncPCABI0(libc_pread_trampoline), uintptr(fd), uintptr(_p0), uintptr(len(p)), uintptr(offset), 0, 0)
	n = int(r0)
	if n <= 0 && e1 != 0 && e1 < 300 {
		err = errnoErr(e1)
	}
	return
}

func pwrite(fd int, p []byte, offset int64) (n int, err error) {
	var _p0 unsafe.Pointer
	if len(p) > 0 {
		_p0 = unsafe.Pointer(&p[0])
	} else {
		_p0 = unsafe.Pointer(&_zero)
	}
	r0, _, e1 := syscall6Xerrno(abi.FuncPCABI0(libc_pwrite_trampoline), uintptr(fd), uintptr(_p0), uintptr(len(p)), uintptr(offset), 0, 0)
	n = int(r0)
	if n <= 0 && e1 != 0 && e1 < 300 {
		err = errnoErr(e1)
	}
	return
}

func Truncate(path string, length int64) (err error) {
	var _p0 *byte
	_p0, err = BytePtrFromString(path)
	if err != nil {
		return
	}
	_, _, e1 := syscall(abi.FuncPCABI0(libc_truncate_trampoline), uintptr(unsafe.Pointer(_p0)), uintptr(length), 0)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}

func Seek(fd int, offset int64, whence int) (newoffset int64, err error) {
	r0, _, e1 := syscallX(abi.FuncPCABI0(libc_lseek_trampoline), uintptr(fd), uintptr(offset), uintptr(whence))
	newoffset = int64(r0)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}
