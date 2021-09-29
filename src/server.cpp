#include <sys/epoll.h>
#include <sys/socket.h>

#include <iostream>

void run_main(const char* host, const char* serv) {
  std::cout << "host=" << host << ", serv=" << serv << "\n";

  int server = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
  if (server == -1) {
    return;
  }
}

int main(int ac, char* av[]) {
  if (ac < 3) {
    std::cout << av[0] << " host serv\n";
    return 1;
  }

  const char* host = av[1];
  const char* serv = av[2];
  try {
    run_main(host, serv);
    return 0;
  } catch (const std::exception& e) {
    std::cerr << e.what() << "\n";
  } catch (...) {
    std::cerr << "unknown exception" << "\n";
  }

  return 1;
}
