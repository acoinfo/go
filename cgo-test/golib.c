/* golib.c - SylixOS cgo support library */

/* These two symbols are required by Go's cgo runtime.
 * They are normally defined in gcc_libinit.c / gcc_util.c
 * but the external linker on SylixOS needs them exported from a shared lib.
 */

void x_cgo_init(void *g, void (*setg)(void*), void **tlsg, void **tlsbase) {
    /* Called once during Go runtime startup to initialize cgo TLS */
    if (tlsg) *tlsg = 0;
    if (tlsbase) *tlsbase = 0;
}

void _cgo_sys_thread_start(void *ts) {
    /* Called when Go needs a new OS thread for cgo.
     * ts is a ThreadStart* with {M *m; G *g; uintptr *tls;}
     * For now, stub implementation. */
}
