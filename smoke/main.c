#include <sys/prx.h>

/* CI-only module. No console behavior is claimed or exercised here. */
int module_start(unsigned int args, void *argp)
{
    (void)args;
    (void)argp;
    return 0;
}

int module_stop(unsigned int args, void *argp)
{
    (void)args;
    (void)argp;
    return 0;
}
