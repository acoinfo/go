// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build sylixos

package runtime

import (
	"unsafe"
)

// Don't split the stack as this function may be invoked without a valid G,
// which prevents us from allocating more stack.
//
//go:nosplit
func sysAllocOS(n uintptr, vmaName string) unsafe.Pointer {
	p, err := mmap(nil, n, _PROT_READ|_PROT_WRITE, _MAP_ANON|_MAP_PRIVATE, -1, 0)
	if err != 0 {
		return nil
	}
	setVMAName(p, n, vmaName)
	return p
}

// sysUnusedOS tells the kernel that the physical pages backing [v, v+n) may be
// reclaimed, while keeping the virtual reservation alive so that a later
// sysUsedOS can re-commit the very same range.
//
// SylixOS facts, measured on RK3568 / SylixOS 3.9.0 (not assumed):
//   - there is no madvise().
//   - posix_madvise(POSIX_MADV_DONTNEED) EXISTS and returns 0 ("success"), but
//     is a silent no-op: it releases no physical pages at all. Do not use it.
//   - remapping the range PROT_NONE with MAP_FIXED does release the physical
//     pages, keeps the virtual address, and the range can be re-committed
//     afterwards. That is what this function does.
//   - PROT_NONE is *required*: remapping the same range RW with MAP_FIXED
//     releases nothing at all (measured: VMM free unchanged, and the old
//     contents are still readable). SylixOS's MAP_FIXED only changes the
//     protection of an existing mapping rather than rebuilding it, so the RW
//     variant is a no-op -- unlike Linux, where MAP_FIXED does drop the pages.
//     Hence sysUsedOS cannot be an empty function here.
//
// Safety: the only caller is the scavenger (mgcscavenge.go). It marks the range
// as allocated in the page allocator and drops the heap lock before calling, so
// no allocation path can hand this memory out while it is being discarded --
// the contents are forfeit by construction.
//
// This is destructive (the range becomes unreadable until sysUsedOS runs), so
// GODEBUG=harddecommit=-1 restores the old no-op behaviour without a rebuild.
// Note the polarity differs from Linux: upstream hard-decommits only when
// harddecommit > 0, whereas here it is ON by default (that is the point of the
// fix) and a negative value turns it off.
//
// Known cost, accepted: address-space fragmentation.
//
// mmap(MAP_FIXED) is a VMA-level operation -- each call splits the mapping, so
// repeated scavenging grows the number of VMM regions without bound. Measured
// on the same etcd write load (`mmaps` row count, same board):
//
//	sysUnusedOS as a no-op :   54 ->   97  regions
//	sysUnusedOS implemented: 2718 -> 6282  regions   (83x)
//
// etcd kept working normally at 6282 regions and the write rate did not
// degrade, but the growth is linear and shows no sign of converging, so the
// practical ceiling is not known.
//
// This is a deliberate trade-off, not an oversight. Every alternative was
// measured on hardware and none of them reclaims a single page:
//
//	mprotect(PROT_NONE)                -> returns 0, releases 0 bytes
//	posix_madvise(POSIX_MADV_DONTNEED) -> returns 0, releases 0 bytes
//	mmap(RW, MAP_FIXED)                -> releases nothing (re-protects only)
//
// Only PROT_NONE + MAP_FIXED drops physical pages, so the fragmentation is the
// price of being able to reclaim at all. On Linux the cheap primitive (madvise)
// exists and this path is a debug-only option; SylixOS has no equivalent.
func sysUnusedOS(v unsafe.Pointer, n uintptr) {
	if debug.harddecommit < 0 || n == 0 {
		return
	}
	if uintptr(v)&(physPageSize-1) != 0 || n&(physPageSize-1) != 0 {
		// SylixOS's mmap rounds the length up to its own page size, so an
		// unaligned range would remap *more* than intended -- and unlike
		// Linux's madvise, MAP_FIXED makes those extra pages unreadable
		// rather than merely over-releasing them.
		throw("unaligned sysUnused")
	}
	if p, err := mmap(v, n, _PROT_NONE, _MAP_ANON|_MAP_PRIVATE|_MAP_FIXED, -1, 0); p != v || err != 0 {
		// Failing silently would leave the allocator's accounting claiming
		// these pages were released when they were not.
		print("runtime: sysUnused mmap(", v, ", ", n, ") = ", p, ", errno ", err, "\n")
		throw("runtime: cannot discard pages in address space")
	}
}

// sysUsedOS re-commits a range previously dropped by sysUnusedOS.
//
// mprotect rather than mmap(MAP_FIXED), for two independent reasons:
//
//  1. It is non-destructive. sysUsed's contract (mem.go) permits v/n to cover
//     memory that is not in the Prepared state, and it is called that way in
//     practice -- allocSpan (mheap.go) passes a whole freshly taken span, of
//     which only part may have been scavenged ("sysUsed all the pages that are
//     actually available in the span since some of them might be scavenged").
//     An operation that discards contents would be leaning on an invariant the
//     contract does not actually state. mprotect only changes protection:
//     already-Ready pages keep their contents, PROT_NONE pages fault back in
//     on first touch.
//
//  2. On SylixOS, mmap(MAP_FIXED) could not do this job anyway. Measured: it
//     leaves an existing mapping's contents untouched, so it is not the
//     "recreate this range" primitive it is on Linux (see sysUnusedOS above,
//     where the same difference is what forces PROT_NONE rather than RW).
func sysUsedOS(v unsafe.Pointer, n uintptr) {
	if n == 0 {
		return
	}
	// The return value is deliberately ignored, and this must NOT be turned
	// into a check -- neither throw nor print.
	//
	// On SylixOS mprotect fails here as a matter of course: measured on
	// RK3568, essentially every call during runtime startup returns -1
	// (e.g. mprotect(0x40048002000, 8192) = -1), clustered in one region of
	// the heap arena. sysUsed is also called on ranges that were never
	// discarded, and on ranges that are only partly mapped, where there is
	// nothing to restore and failing is expected.
	//
	// Both alternatives were tried on hardware and are wrong: throwing kills
	// the runtime during startup, and printing floods the log with a line per
	// call. Ignoring the result is what makes this work.
	//
	// Residual risk, kept here for whoever debugs this next: if a range that
	// *was* discarded by sysUnusedOS fails to be restored, the pages stay
	// PROT_NONE and the next write to them takes a SIGSEGV whose stack points
	// here. That has not been observed -- etcd runs a full write load with
	// this code -- but if a stray SIGSEGV shows up in Go heap code, this is
	// the first thing to suspect.
	mprotect(v, n, _PROT_READ|_PROT_WRITE)
}

func sysHugePageOS(v unsafe.Pointer, n uintptr) {
}

// Don't split the stack as this function may be invoked without a valid G,
// which prevents us from allocating more stack.
//
//go:nosplit
func sysFreeOS(v unsafe.Pointer, n uintptr) {
	if v != nil {
		munmap(v, n)
	}
}

func sysFaultOS(v unsafe.Pointer, n uintptr) {
	mmap(v, n, _PROT_NONE, _MAP_ANON|_MAP_PRIVATE|_MAP_FIXED, -1, 0)
}

func sysReserveOS(v unsafe.Pointer, n uintptr, vmaName string) unsafe.Pointer {
	p, err := mmap(v, n, _PROT_NONE, _MAP_ANON|_MAP_PRIVATE, -1, 0)
	// On sylixos, when mmap anon|private with prot_none returns 0xc,
	// it means no virts mem space left on sylixos VMM.
	if err == _ENOMEM {
		throw("runtime: out of memory")
	}
	if err != 0 {
		return nil
	}
	setVMAName(p, n, vmaName)
	return p
}

func sysMapOS(v unsafe.Pointer, n uintptr, vmaName string) {
	p, err := mmap(v, n, _PROT_READ|_PROT_WRITE, _MAP_ANON|_MAP_FIXED|_MAP_PRIVATE, -1, 0)
	if err == _ENOMEM {
		throw("runtime: out of memory")
	}
	if p != v || err != 0 {
		print("runtime: mmap(", v, ", ", n, ") returned ", p, ", ", err, "\n")
		throw("runtime: cannot map pages in arena address space")
	}
	setVMAName(p, n, vmaName)
}

func sysNoHugePageOS(v unsafe.Pointer, n uintptr) {
}

func sysHugePageCollapseOS(v unsafe.Pointer, n uintptr) {
}
