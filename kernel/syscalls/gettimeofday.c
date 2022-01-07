#include <lwip/sockets.h>
#include <hermit/hermitux_syscalls.h>
#include <hermit/logging.h>
#include <hermit/processor.h>

extern unsigned long long syscall_freq;
extern unsigned long long syscall_boot_tsc;

inline static unsigned long long gtod_rdtsc(void)
{
	unsigned int lo, hi;

	asm volatile ("rdtsc" : "=a"(lo), "=d"(hi) :: "memory");

	return ((unsigned long long)hi << 32ULL | (unsigned long long)lo);
}

int sys_gettimeofday(struct timeval *tv, struct timezone *tz) {

	if(unlikely(tz)) {
		LOG_ERROR("gettimeofday: tz should be null\n");
		return -EINVAL;
	}

	if(likely(tv)) {
		unsigned long long diff = gtod_rdtsc() - syscall_boot_tsc;
		tv->tv_sec = diff/syscall_freq;
		tv->tv_usec = (diff - tv->tv_sec*syscall_freq) / (syscall_freq/1000000ULL);

		return 0;
	}

	LOG_ERROR("gettimeofday: tv is null\n");
	return -EINVAL;
}
