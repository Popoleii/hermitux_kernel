#include <hermit/syscall.h>
#include <lwip/sockets.h>
#include <hermit/logging.h>

extern int hermit_bind(int fd, struct sockaddr *addr, socklen_t addrlen);

/* FIXME allow more generic bind, and on different ports */
int sys_bind(int fd, struct sockaddr *addr, int addrlen) {
#ifndef NO_NET
	struct sockaddr_in sa_server;
	struct in_addr addr_local;

	addr_local.s_addr = INADDR_ANY;
	
	in_port_t *port = (in_port_t *) &addr->sa_data; 

	memset((char *) &sa_server, 0x00, sizeof(sa_server));
	sa_server.sin_family = AF_INET;
	sa_server.sin_addr = addr_local;

	sa_server.sin_port = *port;
	return hermit_bind(fd, (struct sockaddr *) &sa_server, sizeof(sa_server));
	//return bind(fd, addr, addrlen);
#else
	LOG_ERROR("Network disabled, cannot process bind syscall!\n");
	return -ENOSYS;
#endif /* NO_NET */
}
