// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm

package syscall

import (
	"internal/abi"
	"unsafe"
)

// On ARM32 off_t is 64-bit while pointers are 32-bit. The ARM AAPCS places
// a 64-bit argument in an even/odd register pair or on the stack with
// 8-byte alignment, so the LP64 wrappers in syscall_sylixos_64.go (which
// pass an int64 as a single uintptr) cannot be used. These wrappers split
// the value into low/high words and use the existing syscall6/syscall10
// argument slots to build the layout GCC produces:
//
//	lseek(fd, off, whence):      r0=fd  r1=pad  r2:r3=off   stack[0]=whence
//	pread/pwrite(fd,b,n,off):    r0=fd  r1=b    r2=n  r3=pad  stack[0:4]=off
//	truncate(path,len):          r0=path  r1=pad  r2:r3=len
//	ftruncate(fd,len):           r0=fd  r1=pad  r2:r3=len
//	mmap64(...,fd,off):          r0-r3=addr/len/prot/flags
//	                             stack[0]=fd stack[4]=pad stack[8:12]=off

func mmap(addr uintptr, length uintptr, prot int, flag int, fd int, pos int64) (ret uintptr, err error) {
	r0, _, e1 := syscall10(abi.FuncPCABI0(libc_mmap_trampoline),
		addr, length, uintptr(prot), uintptr(flag), uintptr(fd), 0,
		uintptr(uint64(pos)), uintptr(uint64(pos)>>32), 0, 0)
	ret = r0
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}

func Ftruncate(fd int, length int64) (err error) {
	_, _, e1 := syscall6(abi.FuncPCABI0(libc_ftruncate_trampoline),
		uintptr(fd), 0, uintptr(uint64(length)), uintptr(uint64(length)>>32), 0, 0)
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
	r0, _, e1 := syscall6(abi.FuncPCABI0(libc_pread_trampoline),
		uintptr(fd), uintptr(_p0), uintptr(len(p)), 0,
		uintptr(uint64(offset)), uintptr(uint64(offset)>>32))
	n = int(r0)
	if e1 != 0 {
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
	r0, _, e1 := syscall6(abi.FuncPCABI0(libc_pwrite_trampoline),
		uintptr(fd), uintptr(_p0), uintptr(len(p)), 0,
		uintptr(uint64(offset)), uintptr(uint64(offset)>>32))
	n = int(r0)
	if e1 != 0 {
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
	_, _, e1 := syscall6(abi.FuncPCABI0(libc_truncate_trampoline),
		uintptr(unsafe.Pointer(_p0)), 0, uintptr(uint64(length)), uintptr(uint64(length)>>32), 0, 0)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}

func Seek(fd int, offset int64, whence int) (newoffset int64, err error) {
	r0, r1, e1 := syscall6X(abi.FuncPCABI0(libc_lseek_trampoline),
		uintptr(fd), 0, uintptr(uint64(offset)), uintptr(uint64(offset)>>32), uintptr(whence), 0)
	newoffset = int64(uint64(r0) | uint64(r1)<<32)
	if e1 != 0 {
		err = errnoErr(e1)
	}
	return
}
