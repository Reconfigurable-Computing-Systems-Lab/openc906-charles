#ifndef _STUB_SYS_SYSCALL_H
#define _STUB_SYS_SYSCALL_H
#define __NR_gettid 0
static inline long syscall(long num, ...) { (void)num; return 0; }
#endif
