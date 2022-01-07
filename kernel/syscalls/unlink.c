#include <hermit/syscall.h>
#include <hermit/spinlock.h>
#include <asm/uhyve.h>
#include <asm/page.h>
#include <hermit/logging.h>
#include <hermit/minifs.h>

extern spinlock_irqsave_t lwip_lock;
extern volatile int libc_sd;

typedef struct {
	const char* pathname;
	int ret;
} __attribute__((packed)) uhyve_unlink_t;


int sys_unlink(const char *pathname) {

	if(unlikely(!pathname)) {
		LOG_ERROR("unlink: pathname is null\n");
		return -EINVAL;
	}

#ifndef NO_NET
	int s, sysnr, i, len, ret;
#endif /* NO_NET */

	if(is_uhyve()) {

		if(minifs_enabled)
			return minifs_unlink(pathname);

		uhyve_unlink_t uhyve_args = { (const char *) virt_to_phys((size_t) pathname), 0};
		uhyve_send(UHYVE_PORT_UNLINK, (unsigned)virt_to_phys((size_t)&uhyve_args));
		return uhyve_args.ret;
	}

#ifndef NO_NET

	spinlock_irqsave_lock(&lwip_lock);
	s = libc_sd;

	sysnr = __NR_unlink;
	lwip_write(s, &sysnr, sizeof(sysnr));

	len = strlen(pathname);
	lwip_write(s, &len, sizeof(len));

	i=0;
	while(i < len)
	{
		ret = lwip_write(s, (char*)pathname+i, len-i);
		if (ret < 0) {
			spinlock_irqsave_unlock(&lwip_lock);
			return ret;
		}

		i += ret;
	}

	ret = lwip_read(s, &i, sizeof(i));
	if (ret < 0)
		i = ret;

	spinlock_irqsave_unlock(&lwip_lock);

	return i;

#endif /* NO_NET */
	LOG_ERROR("unlink: network disabled, cannot use qemu isle\n");
	return -ENOSYS;
}

