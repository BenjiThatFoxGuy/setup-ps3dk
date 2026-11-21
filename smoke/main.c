#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <ppu-types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/lv2_syscall.h>
#include <sys/timer.h>
#include <cell/fs/cell_fs_file_api.h>

/* Native sysPrxForUser imports, not process-runtime thread trampolines. */
extern int sys_ppu_thread_create(u64 *, void (*)(u64), u64, int, size_t, u64, const char *);
extern u64 sys_time_get_system_time(void);
extern u32 vshmain_EB757101(void);
static volatile int result;

static void worker(u64 arg)
{
    (void)arg;
    sys_timer_usleep(1000);
    lv2syscall1(41, 0);
}

static int raw_open(const char *path, int *fd)
{
    lv2syscall6(801, (u64)(uintptr_t)path, 0, (u64)(uintptr_t)fd, 0, 0, 0);
    return_to_user_prog(int);
}

/* Link/import fixture only. This module must not be installed on a console. */
int module_start(unsigned int args, void *argp)
{
    char message[96], copy[96];
    struct sockaddr_in address;
    u64 thread = 0, bytes = 0;
    int fd = -1;
    int s = socket(AF_INET, SOCK_DGRAM, 0);
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    result = snprintf(message, sizeof(message), "sdk %u %llu", args,
                      (unsigned long long)sys_time_get_system_time());
    memcpy(copy, message, sizeof(copy));
    result = bind(s, (struct sockaddr *)&address, sizeof(address));
    result = (int)send(s, copy, strlen(message), 0);
    result = socketclose(s);
    result = sys_ppu_thread_create(&thread, worker, 0, 1500, 16384, 1, "sdk_smoke");
    result = raw_open("/dev_hdd0/sdk-smoke-do-not-run", &fd);
    result = cellFsOpen("/dev_hdd0/sdk-smoke-do-not-run", CELL_FS_O_RDONLY, &fd, NULL, 0);
    result = cellFsRead(fd, copy, sizeof(copy), &bytes);
    result = cellFsClose(fd);
    result = (int)vshmain_EB757101();
    (void)argp;
    return 0;
}

int module_stop(unsigned int args, void *argp)
{
    (void)args;
    (void)argp;
    return 0;
}
