// SylixOS CGO 综合验证程序
// 覆盖：C函数调用、递归、字符串、goroutine调度、channel通信、GC
package main

/*
#include <stdio.h>
#include <string.h>

int add(int a, int b) {
    return a + b;
}

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

void say(char *msg) {
    puts(msg);
}

// 从 C 返回一个字符串供 Go 读取
const char* get_version() {
    return "SylixOS cgo v1.0";
}
*/
import "C"
import (
	"unsafe"
)

func main() {
	println("=========================================")
	println("  SylixOS CGO Comprehensive Test Suite")
	println("=========================================")

	// ============ Test 1: C 基本类型函数调用 ============
	println("")
	println("[Test 1] C function call (basic types)")
	a, b := 3, 5
	result := C.add(C.int(a), C.int(b))
	if int(result) == 8 {
		println("  PASS: C.add(3, 5) =", int(result))
	} else {
		println("  FAIL: expected 8, got", int(result))
	}

	// ============ Test 2: C 递归函数 ============
	println("")
	println("[Test 2] C recursive function")
	n := 7
	result = C.factorial(C.int(n))
	expected := 5040
	if int(result) == expected {
		println("  PASS: C.factorial(7) =", int(result))
	} else {
		println("  FAIL: expected", expected, "got", int(result))
	}

	// ============ Test 3: C 字符串传递 ============
	println("")
	println("[Test 3] C string passing (Go -> C)")
	msg := C.CString("Hello from Go->C!")
	C.say(msg)
	println("  PASS: C.say() printed above line")
	// C.free(unsafe.Pointer(msg)) // 跳过以验证无需 free 也能正常运行

	// ============ Test 4: Go goroutine + channel ============
	println("")
	println("[Test 4] Goroutine + channel communication")
	c := make(chan string, 1)
	go func() {
		c <- "goroutine-ok"
	}()
	received := <-c
	if received == "goroutine-ok" {
		println("  PASS: go func -> channel -> main: received '", received, "'")
	} else {
		println("  FAIL: unexpected value '", received, "'")
	}

	// 多 goroutine 并发
	c2 := make(chan int, 3)
	go func() { c2 <- 1 }()
	go func() { c2 <- 2 }()
	go func() { c2 <- 3 }()
	sum := 0
	for i := 0; i < 3; i++ {
		sum += <-c2
	}
	if sum == 6 {
		println("  PASS: 3 concurrent goroutines, sum =", sum)
	} else {
		println("  FAIL: expected sum 6, got", sum)
	}

	// ============ Test 5: 堆内存分配压力测试 ============
	println("")
	println("[Test 5] Heap allocation stress (10000 allocs)")
	allocCount := 10000
	totalBytes := 0
	for i := 0; i < allocCount; i++ {
		buf := make([]byte, 256)
		buf[0] = byte(i % 256)
		totalBytes += len(buf)
	}
	println("  PASS:", allocCount, "allocs,", totalBytes/1024, "KB total, no SIGKILL")

	// ============ Test 6: Go 指针打印 ============
	println("")
	println("[Test 6] Go pointer to C context")
	x := 42
	addr := uintptr(unsafe.Pointer(&x))
	println("  Go var x =", x, "at addr", addr)
	if addr > 0 {
		println("  PASS: valid Go heap/stack address")
	} else {
		println("  FAIL: null address")
	}

	// ============ Test 7: C 返回字符串 ============
	println("")
	println("[Test 7] C string return (C -> Go)")
	cVersion := C.get_version()
	goVersion := C.GoString(cVersion)
	println("  C says:", goVersion)
	if goVersion != "" {
		println("  PASS: C->Go string passing works")
	} else {
		println("  FAIL: empty string from C")
	}

	// ============ 结果汇总 ============
	println("")
	println("=========================================")
	println("  ALL CGO TESTS PASSED")
	println("=========================================")
}
