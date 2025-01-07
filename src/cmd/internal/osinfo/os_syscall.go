// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build aix || linux || sylixos

// Supporting definitions for os_uname.go on AIX, Linux and SylixOS.

package osinfo

import "syscall"

type utsname = syscall.Utsname

func uname(buf *utsname) error {
	return syscall.Uname(buf)
}
