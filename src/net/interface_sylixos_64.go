// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos && (amd64 || arm64)

package net

// ifreqIfruSize is sizeof(((struct ifreq *)0)->ifr_ifru) on LP64.
// struct sockaddr is 28 bytes, but the union also contains ifru_data,
// a pointer, which forces 8-byte alignment; the union is therefore
// rounded up to 32 bytes and the whole struct to 16+32 = 48 bytes.
const ifreqIfruSize = 32
