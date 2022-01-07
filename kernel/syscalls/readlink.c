#include <hermit/syscall.h>
#include <hermit/logging.h>
#include <asm/uhyve.h>
#include <asm/page.h>
#include <hermit/stddef.h>
#include <hermit/minifs.h>

typedef struct {
	char *path;
	char* buf;
	int bufsz;
	ssize_t ret;
} __attribute__((packed)) uhyve_readlink_t;

int sys_readlink(char *path, char *buf, int bufsiz) {

	if(minifs_enabled) {
		LOG_ERROR("readlink (%s) currently not supported with minifs\n",
				path);
		return -ENOSYS;
	}

	if(unlikely(!path || !buf)) {
		LOG_ERROR("readlink: path or buf is null\n");
		return -EINVAL;
	}

	if (likely(is_uhyve())) {
		/* Let's get a physically contiguous buffer to avoid any issue with
		 * the host filling it */
		char *phys_buf = kmalloc(bufsiz);
		if(!phys_buf)
			return -ENOMEM;

		uhyve_readlink_t args = {(char *) virt_to_phys((size_t) path),
            (char*) virt_to_phys((size_t) phys_buf), bufsiz, -1};

		uhyve_send(UHYVE_PORT_READLINK, (unsigned)virt_to_phys((size_t)&args));
		memcpy(buf, phys_buf, bufsiz);

		kfree(phys_buf);
		return args.ret;
	}

	LOG_INFO("readlink: not supported with qemu isle\n");
	return -ENOSYS;
}
