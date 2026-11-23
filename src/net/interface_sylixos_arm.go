// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && arm

package net

// ifreqIfruSize is sizeof(((struct ifreq *)0)->ifr_ifru) on ILP32.
// The union is dominated by struct sockaddr (28 bytes) and has 4-byte
// alignment, so the whole struct is 16+28 = 44 bytes.
const ifreqIfruSize = 28
