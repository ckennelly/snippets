/* LD_PRELOAD shim: keep modules mapped so LSan can symbolize their frames. */
int dlclose(void *handle) { (void)handle; return 0; }
