#include <stdio.h>
#include <stdlib.h>
#include <netdb.h>
#include <arpa/inet.h>

void run(const char *host)
{
  struct addrinfo hints = {
    .ai_family = PF_UNSPEC,
    .ai_socktype = SOCK_STREAM,
    .ai_flags = AI_CANONNAME
  };

  struct addrinfo *res;
  if (getaddrinfo(host, NULL, &hints, &res) != 0) {
    perror("getaddrinfo");
    exit(1);
  }

  void *addr;
  switch (res->ai_family)
  {
  case AF_INET:
    addr = &((struct sockaddr_in *) res->ai_addr)->sin_addr;
    break;
  case AF_INET6:
    addr = &((struct sockaddr_in6 *) res->ai_addr)->sin6_addr;
    break;
  }
  char addrstr[100];
  inet_ntop(res->ai_family, addr, addrstr, 100);

  printf("Host: %s\n", host);
  printf ("IPv%d address: %s (%s)\n", res->ai_family == PF_INET6 ? 6 : 4,
          addrstr, res->ai_canonname);

  freeaddrinfo(res);
}

int main(void) {
  run("localhost");
}
