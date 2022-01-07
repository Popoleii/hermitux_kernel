#include <hermit/syscall.h>
#include <hermit/spinlock.h>
#include <asm/uhyve.h>
#include <asm/page.h>
#include <hermit/logging.h>
#include <hermit/minifs.h>

extern spinlock_irqsave_t lwip_lock;
extern volatile int libc_sd;

#ifndef NO_NET

typedef struct {
	int sysnr;
	int fd;
} __attribute__((packed)) sys_close_t;

#endif /* NO_DEV */

typedef struct {
        int fd;
        int ret;
} __attribute__((packed)) uhyve_close_t;

extern int hermit_close(int fd);

int sys_close(int fd)
{

	if (likely(is_uhyve())) {

#ifndef NO_NET
		// do we have an LwIP file descriptor?
		if (fd & LWIP_FD_BIT) {
			int ret = hermit_close(fd);
			if (ret < 0)
				return -errno;

			return ret;
		}
#endif

		if(minifs_enabled)
			return minifs_close(fd);

		uhyve_close_t uhyve_close = {fd, -1};

		uhyve_send(UHYVE_PORT_CLOSE, (unsigned)virt_to_phys((size_t) &uhyve_close));

		return uhyve_close.ret;
	}

#ifndef NO_NET

	int ret, s;
	sys_close_t sysargs = {__NR_close, fd};

	// do we have an LwIP file descriptor?
	if (fd & LWIP_FD_BIT) {
		ret = lwip_close(fd & ~LWIP_FD_BIT);
		if (ret < 0)
			return -errno;

		return 0;
	}

	spinlock_irqsave_lock(&lwip_lock);
	if (libc_sd < 0) {
		ret = 0;
		goto out;
	}

	s = libc_sd;
	ret = lwip_write(s, &sysargs, sizeof(sysargs));
	if (ret != sizeof(sysargs))
		goto out;
	lwip_read(s, &ret, sizeof(ret));

out:
	spinlock_irqsave_unlock(&lwip_lock);

	return ret;

#else /*NO_NET */

	LOG_ERROR("close: network disabled, cannot use qemu isle\n");
	return -ENOSYS;

#endif /* NO_NET */
}


