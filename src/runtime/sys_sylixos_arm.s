// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// System calls and other sys.stuff for arm, SylixOS
// System calls are implemented in libvpmpdm, this file
// contains trampolines that convert from Go to C calling convention.
//

//go:build sylixos && arm

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// Native store/store barrier for ARMv7+, same as the other arm ports.
TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
	B	runtime·armPublicationBarrier(SB)

// Trampoline frames: a non-leaf function with declared frame $4 gets
// a total frame of 8 bytes (LR + 4 locals), which keeps R13 8-byte
// aligned as required by the ARM C ABI at a BL to libc. Registers
// R4-R11 must be preserved across a C call; R4 is saved in the
// declared locals when the args pointer is needed after the call.

// mstart_stub is the first function executed on a new thread started by pthread_create.
// It just does some low-level setup and then calls mstart.
// Note: called with the C calling convention.
TEXT runtime·mstart_stub(SB),NOSPLIT,$0
	// R0 points to the m.
	// We are already on m's g0 stack.

	// Save callee-save registers.
	MOVM.DB.W [R4-R11], (R13)

	MOVW	m_g0(R0), g
	BL	·save_g(SB)

	BL	runtime·mstart(SB)

	// Restore callee-save registers.
	MOVM.IA.W (R13), [R4-R11]

	// Go is all done with this OS thread.
	MOVW	$0, R0

	RET

TEXT runtime·sigfwd(SB),NOSPLIT,$0-16
	MOVW	sig+4(FP), R0
	MOVW	info+8(FP), R1
	MOVW	ctx+12(FP), R2
	MOVW	fn+0(FP), R3
	MOVW	R13, R9
	SUB	$24, R13
	BIC	$0x7, R13		// align for ELF ABI
	BL	(R3)
	MOVW	R9, R13
	RET

TEXT runtime·sigtramp(SB),NOSPLIT|TOPFRAME,$0
	// Reserve space for callee-save registers and arguments.
	MOVM.DB.W [R4-R11], (R13)
	SUB	$16, R13

	// SylixOS enters a signal handler with a fresh register context
	// built by archSrtpCtxCreate, so R10 holds the handler entry point,
	// not g. Enter with the thread's g0 from TLS, then take the
	// interrupted g from R10 when the signal was delivered in Go code.
	MOVW	R0, 4(R13)		// signum
	MOVW	R1, 8(R13)		// info
	MOVW	R2, 12(R13)		// ctx
	BL	runtime·load_g(SB)
	MOVW	64(R2), R4		// interrupted pc
	MOVW	$runtime·text(SB), R3
	CMP	R3, R4
	B.LO	sigtramp_notgo
	MOVW	$runtime·etext(SB), R3
	CMP	R3, R4
	B.HS	sigtramp_notgo
	MOVW	52(R2), g		// ARCH_REG_CTX.r10
sigtramp_notgo:
	BL	runtime·sigtrampgo(SB)

	// Restore callee-save registers.
	ADD	$16, R13
	MOVM.IA.W (R13), [R4-R11]

	RET

TEXT runtime·pthread_attr_init_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_pthread_attr_init(SB)
	RET

TEXT runtime·pthread_attr_destroy_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_pthread_attr_destroy(SB)
	RET

TEXT runtime·pthread_attr_setdetachstate_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_pthread_attr_setdetachstate(SB)
	RET

TEXT runtime·pthread_create_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$8, R13
	MOVW	0(R4), R1		// arg 2 - attr
	MOVW	4(R4), R2		// arg 3 - start
	MOVW	8(R4), R3		// arg 4 - arg
	MOVW	R13, R0			// arg 1 - &threadid (discard)
	CALL	libc_pthread_create(SB)
	ADD	$8, R13
	MOVW	4(R13), R4
	RET

TEXT runtime·pthread_kill_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_pthread_kill(SB)
	RET

TEXT runtime·pthread_self_trampoline(SB),NOSPLIT,$4
	CALL	libc_pthread_self(SB)
	RET

TEXT runtime·pthread_attr_setstack_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_pthread_attr_setstack(SB)
	RET

TEXT runtime·sysconf_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_sysconf(SB)
	RET

TEXT runtime·raise_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_raise(SB)
	RET

TEXT runtime·malloc_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	MOVW	0(R4), R0
	CALL	libc_malloc(SB)
	MOVW	R0, 4(R4)
	MOVW	4(R13), R4
	RET

TEXT runtime·sem_init_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_sem_init(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sem_init_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
sem_init_ok:
	RET

TEXT runtime·sem_post_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_sem_post(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sem_post_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
sem_post_ok:
	RET

TEXT runtime·sem_reltimedwait_np_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_sem_reltimedwait_np(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sem_reltimedwait_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
sem_reltimedwait_ok:
	RET

TEXT runtime·sem_wait_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_sem_wait(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sem_wait_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
sem_wait_ok:
	RET

TEXT runtime·exit_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_exit(SB)
	MOVW	$0, R0
	MOVW	R0, (R0)
	RET

TEXT runtime·pthread_exit_trampoline(SB),NOSPLIT,$4
	CALL	libc_pthread_exit(SB)
	MOVW	$0, R0
	MOVW	R0, (R0)
	RET

TEXT runtime·raiseproc_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	CALL	libc_getpid(SB)
	MOVW	0(R4), R1
	CALL	libc_kill(SB)
	MOVW	4(R13), R4
	RET

TEXT runtime·sched_yield_trampoline(SB),NOSPLIT,$4
	CALL	libc_sched_yield(SB)
	RET

TEXT runtime·mmap_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$16, R13
	MOVW	0(R4), R0		// addr
	MOVW	4(R4), R1		// len
	MOVW	8(R4), R2		// prot
	MOVW	12(R4), R3		// flags
	MOVW	16(R4), R12		// fid
	MOVW	R12, 0(R13)		// arg 5 on stack
	MOVW	20(R4), R12		// offset (low)
	MOVW	R12, 8(R13)		// arg 6, 64-bit off_t, 8-aligned
	MOVW	$0, R12
	MOVW	R12, 12(R13)
	CALL	libc_mmap(SB)
	ADD	$16, R13
	MOVW	$0, R1
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	mmap_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
mmap_ok:
	MOVW	R0, 24(R4)
	MOVW	R1, 28(R4)
	MOVW	4(R13), R4
	RET

TEXT runtime·munmap_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_munmap(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	munmap_ok
	MOVW	$0, R0
	MOVW	R0, (R0)
munmap_ok:
	RET

TEXT runtime·open_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	MOVW	$0, R3			// varargs
	CALL	libc_open(SB)
	RET

TEXT runtime·close_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_close(SB)
	RET

TEXT runtime·read_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_read(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	read_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
read_ok:
	RET

TEXT runtime·write_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_write(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	write_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
write_ok:
	RET

TEXT runtime·pipe2_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_pipe2(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	pipe2_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
pipe2_ok:
	RET

TEXT runtime·setitimer_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_setitimer(SB)
	RET

TEXT runtime·usleep_trampoline(SB),NOSPLIT,$4
	MOVW	0(R0), R0
	CALL	libc_usleep(SB)
	RET

TEXT runtime·clock_gettime_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_clock_gettime(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	clock_gettime_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
clock_gettime_ok:
	RET

TEXT runtime·fcntl_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	MOVW	0(R4), R0
	MOVW	4(R4), R1
	MOVW	8(R4), R2
	MOVW	$0, R3			// vararg
	CALL	libc_fcntl(SB)
	MOVW	$0, R1
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	fcntl_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$-1, R0
fcntl_ok:
	MOVW	R0, 12(R4)
	MOVW	R1, 16(R4)
	MOVW	4(R13), R4
	RET

TEXT runtime·sigaction_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_sigaction(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sigaction_ok
	MOVW	$0, R0
	MOVW	R0, (R0)
sigaction_ok:
	RET

TEXT runtime·sigprocmask_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_pthread_sigmask(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sigprocmask_ok
	MOVW	$0, R0
	MOVW	R0, (R0)
sigprocmask_ok:
	RET

TEXT runtime·sigaltstack_trampoline(SB),NOSPLIT,$4
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_sigaltstack(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	sigaltstack_ok
	MOVW	$0, R0
	MOVW	R0, (R0)
sigaltstack_ok:
	RET

TEXT runtime·poll_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_poll(SB)
	MOVW	$-1, R12
	CMP	R12, R0
	BNE	poll_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R1
	MOVW	$0, R0
	SUB	R1, R0, R0
poll_ok:
	RET

TEXT runtime·libc_epoll_create1_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_epoll_create1(SB)

TEXT runtime·libc_epoll_ctl_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_epoll_ctl(SB)

TEXT runtime·libc_epoll_wait_trampoline(SB),NOSPLIT,$0-0
	JMP	libc_epoll_wait(SB)

TEXT runtime·API_VutexPend_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_API_VutexPend(SB)
	RET

TEXT runtime·API_VutexPostEx_trampoline(SB),NOSPLIT,$4
	MOVW	8(R0), R2
	MOVW	4(R0), R1
	MOVW	0(R0), R0
	CALL	libc_API_VutexPostEx(SB)
	RET

TEXT runtime·vprocExitModeSet_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	CALL	libc_getpid(SB)
	MOVW	0(R4), R1
	CALL	libc_vprocExitModeSet(SB)
	MOVW	4(R13), R4
	RET

// syscall calls a function in libc on behalf of the syscall package.
// syscall takes a pointer to a struct like:
// struct {
//	fn    uintptr
//	a1    uintptr
//	a2    uintptr
//	a3    uintptr
//	r1    uintptr
//	r2    uintptr
//	err   uintptr
// }
// syscall must be called on the g0 stack with the
// C calling convention (use libcCall).
//
// syscall expects a 32-bit result and tests for 32-bit -1
// to decide there was an error.
TEXT runtime·syscall(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4

	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	$0, R3			// vararg
	BL	(R12)

	MOVW	R0, (4*4)(R4)		// r1
	MOVW	R1, (5*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscall_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (6*4)(R4)		// err
syscall_ok:
	MOVW	4(R13), R4
	RET

// syscallX is like syscall but expects a 64-bit result
// and tests for 64-bit -1 to decide there was an error.
TEXT runtime·syscallX(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4

	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	$0, R3			// vararg
	BL	(R12)

	MOVW	R0, (4*4)(R4)		// r1
	MOVW	R1, (5*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscallX_ok
	CMP	R12, R1
	BNE	syscallX_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (6*4)(R4)		// err
syscallX_ok:
	MOVW	4(R13), R4
	RET

// syscallXerrno is like syscallX but always reports errno.
TEXT runtime·syscallXerrno(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4

	CALL	libc_errno(SB)
	MOVW	$0, R12
	MOVW	R12, (R0)

	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	$0, R3			// vararg
	BL	(R12)

	MOVW	R0, (4*4)(R4)		// r1
	MOVW	R1, (5*4)(R4)		// r2

	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (6*4)(R4)		// err
	MOVW	4(R13), R4
	RET

// syscallXnull is like syscallX but tests for 64-bit 0 to decide
// there was an error.
TEXT runtime·syscallXnull(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4

	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	$0, R3			// vararg
	BL	(R12)

	MOVW	R0, (4*4)(R4)		// r1
	MOVW	R1, (5*4)(R4)		// r2

	ORR	R1, R0, R12
	CMP	$0, R12
	BNE	syscallXnull_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (6*4)(R4)		// err
syscallXnull_ok:
	MOVW	4(R13), R4
	RET

// syscall6 calls a function in libc on behalf of the syscall package.
// syscall6 takes a pointer to a struct like:
// struct {
//	fn    uintptr
//	a1    uintptr
//	a2    uintptr
//	a3    uintptr
//	a4    uintptr
//	a5    uintptr
//	a6    uintptr
//	r1    uintptr
//	r2    uintptr
//	err   uintptr
// }
TEXT runtime·syscall6(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$8, R13

	MOVW	(5*4)(R4), R12		// a5
	MOVW	R12, 0(R13)
	MOVW	(6*4)(R4), R12		// a6
	MOVW	R12, 4(R13)
	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	(4*4)(R4), R3		// a4
	BL	(R12)

	MOVW	R0, (7*4)(R4)		// r1
	MOVW	R1, (8*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscall6_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (9*4)(R4)		// err
syscall6_ok:
	ADD	$8, R13
	MOVW	4(R13), R4
	RET

// syscall6X is like syscall6 but expects a 64-bit result
// and tests for 64-bit -1 to decide there was an error.
TEXT runtime·syscall6X(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$8, R13

	MOVW	(5*4)(R4), R12		// a5
	MOVW	R12, 0(R13)
	MOVW	(6*4)(R4), R12		// a6
	MOVW	R12, 4(R13)
	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	(4*4)(R4), R3		// a4
	BL	(R12)

	MOVW	R0, (7*4)(R4)		// r1
	MOVW	R1, (8*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscall6X_ok
	CMP	R12, R1
	BNE	syscall6X_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (9*4)(R4)		// err
syscall6X_ok:
	ADD	$8, R13
	MOVW	4(R13), R4
	RET

// syscall6Xerrno is like syscall6X but always reports errno.
TEXT runtime·syscall6Xerrno(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$8, R13

	CALL	libc_errno(SB)
	MOVW	$0, R12
	MOVW	R12, (R0)

	MOVW	(5*4)(R4), R12		// a5
	MOVW	R12, 0(R13)
	MOVW	(6*4)(R4), R12		// a6
	MOVW	R12, 4(R13)
	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	(4*4)(R4), R3		// a4
	BL	(R12)

	MOVW	R0, (7*4)(R4)		// r1
	MOVW	R1, (8*4)(R4)		// r2

	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (9*4)(R4)		// err
	ADD	$8, R13
	MOVW	4(R13), R4
	RET

// syscall10 calls a function in libc on behalf of the syscall package.
// syscall10 takes a pointer to a struct like:
// struct {
//	fn    uintptr
//	a1    uintptr
//	...
//	a10   uintptr
//	r1    uintptr
//	r2    uintptr
//	err   uintptr
// }
TEXT runtime·syscall10(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$24, R13

	MOVW	(5*4)(R4), R12		// a5
	MOVW	R12, 0(R13)
	MOVW	(6*4)(R4), R12		// a6
	MOVW	R12, 4(R13)
	MOVW	(7*4)(R4), R12		// a7
	MOVW	R12, 8(R13)
	MOVW	(8*4)(R4), R12		// a8
	MOVW	R12, 12(R13)
	MOVW	(9*4)(R4), R12		// a9
	MOVW	R12, 16(R13)
	MOVW	(10*4)(R4), R12		// a10
	MOVW	R12, 20(R13)
	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	(4*4)(R4), R3		// a4
	BL	(R12)

	MOVW	R0, (11*4)(R4)		// r1
	MOVW	R1, (12*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscall10_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (13*4)(R4)		// err
syscall10_ok:
	ADD	$24, R13
	MOVW	4(R13), R4
	RET

// syscall10X is like syscall10 but expects a 64-bit result
// and tests for 64-bit -1 to decide there was an error.
TEXT runtime·syscall10X(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	SUB	$24, R13

	MOVW	(5*4)(R4), R12		// a5
	MOVW	R12, 0(R13)
	MOVW	(6*4)(R4), R12		// a6
	MOVW	R12, 4(R13)
	MOVW	(7*4)(R4), R12		// a7
	MOVW	R12, 8(R13)
	MOVW	(8*4)(R4), R12		// a8
	MOVW	R12, 12(R13)
	MOVW	(9*4)(R4), R12		// a9
	MOVW	R12, 16(R13)
	MOVW	(10*4)(R4), R12		// a10
	MOVW	R12, 20(R13)
	MOVW	(0*4)(R4), R12		// fn
	MOVW	(1*4)(R4), R0		// a1
	MOVW	(2*4)(R4), R1		// a2
	MOVW	(3*4)(R4), R2		// a3
	MOVW	(4*4)(R4), R3		// a4
	BL	(R12)

	MOVW	R0, (11*4)(R4)		// r1
	MOVW	R1, (12*4)(R4)		// r2

	MOVW	$-1, R12
	CMP	R12, R0
	BNE	syscall10X_ok
	CMP	R12, R1
	BNE	syscall10X_ok
	CALL	libc_errno(SB)
	MOVW	(R0), R0
	MOVW	R0, (13*4)(R4)		// err
syscall10X_ok:
	ADD	$24, R13
	MOVW	4(R13), R4
	RET

TEXT runtime·issetugid_trampoline(SB),NOSPLIT,$12
	MOVW	R4, 4(R13)
	MOVW	R0, R4
	CALL	libc_issetugid(SB)
	MOVW	R0, 0(R4)
	MOVW	4(R13), R4
	RET
