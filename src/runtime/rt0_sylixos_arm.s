// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm

#include "textflag.h"

// SylixOS calls the entry point like C main(argc, argv), so R0 and R1
// already hold argc and argv; hand them to rt0_go untouched.

TEXT _rt0_arm_sylixos(SB),NOSPLIT|NOFRAME,$0
	B	runtime·rt0_go(SB)
