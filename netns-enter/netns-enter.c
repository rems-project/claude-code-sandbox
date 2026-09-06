#include <argp.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

const char *argp_program_version = "0x03";

#ifndef CFG
#define CFG "/usr/local/etc/netns-enter"
#endif

void die_perror(int code, const char *fn) {
  perror(fn);
  exit(code);
}

void die_fmt(int code, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);
  exit(code);
}

size_t alen(void *vec[]) {
  size_t res = 0;
  while(*(vec++)) ++res;
  return res;
}

FILE *open_cfg(const char *path) {
  int fd = open(path, O_RDONLY);
  if (fd == -1)
    die_perror(1, path);
  struct stat stat = {};
  int res = fstat(fd, &stat);
  if (res == -1)
    die_perror(1, path);
  if (stat.st_uid != 0 || stat.st_gid != 0 || stat.st_mode & S_IWOTH)
    die_fmt(1, "%s: must be owned by root:root and not world writable.\n", path);
  FILE *file = fdopen(fd, "r");
  if (!file)
    die_perror(1, path);
  return file;
}

bool netns_whitelisted(char *netns) {
  FILE *cfg = open_cfg(CFG);
  bool match = false;
  size_t bsize = 0;
  char *buf = NULL;
  ssize_t n;
  while (!match && (n = getline(&buf, &bsize, cfg)) > 0) {
    if (strcmp(buf, "\n") == 0 || strncmp(buf, "#", 1) == 0)
      continue;
    if (buf[n - 1] == '\n')
      buf[n - 1] = '\0';
    if (strcmp(netns, buf) == 0)
      match = true;
  }
  free(buf);
  fclose(cfg);
  return match;
}

const struct argp_option options[] = {
  { "netns", 'n', "NETNSNAME", 0,
    "Target network namespace. Must be whitelisted by the config file (" CFG ")." },
  {}
};

struct args { char *netns; char **cmd; };

error_t parser (int key, char *arg, struct argp_state *state) {
  struct args *args = state->input;
  switch (key) {
    case 'n':
      if (!netns_whitelisted(arg))
        die_fmt(1, "%s: namespace not whitelisted.\n", arg);
      args->netns = arg;
      break;
    case ARGP_KEY_ARGS:
      args->cmd = state->argv + state->next;
      break;
    case ARGP_KEY_ARG: return ARGP_ERR_UNKNOWN;
    default: return ARGP_ERR_UNKNOWN;
  }
  return 0;
};

const struct argp argp = { options, parser,
  .args_doc = "[--] COMMAND [ARGS...]",
  .doc = "Run COMMAND in the network namespace NETNSNAME.",
};

int main (int argc, char **argv) {

  struct args args = {};
  argp_parse(&argp, argc, argv, 0, 0, &args);

  if (!args.netns)
    die_fmt(1, "No namespace given.\n");
  if (!args.cmd || !args.cmd[0])
    die_fmt(1, "No command to run.\n");
  if (getuid() == 0)
    die_fmt(2, "Refusing to run as root.\n");
  if (geteuid() != 0)
    die_fmt(2, "EUID != 0. Are we suid?\n");

  char suid[32], sgid[32];
  snprintf(suid, 32, "%d", getuid());
  snprintf(sgid, 32, "%d", getgid());

  char *cmd[] = {
    "/usr/bin/ip", "netns", "exec", args.netns,
    "/usr/bin/setpriv", "--reuid", suid, "--regid", sgid, "--init-groups", "--",
    NULL,
  };

  int n1 = alen((void**) cmd), n2 = alen((void**) args.cmd);
  size_t size = (n1 + n2 + 1) * sizeof(char *);
  char **exe = malloc(size);
  if (!exe) die_perror(1, "malloc");
  memcpy(exe, cmd, n1 * sizeof(char *));
  memcpy(exe + n1, args.cmd, (n2 + 1) * sizeof(char *));

  /* Leaves the environment untouched — don't depend on it in the privileged
   * phase! */
  if (execv(exe[0], exe) < 0)
    die_perror(1, "exec");

  return 0;
}
