# Where is claude?
CLAUDE_BIN := /opt/claude/bin

# Seccomp filters are arch-dependent
ARCH := $(shell uname -m)

all: claude netns-enter/netns-enter

claude: claude.in seccomp/seccomp.$(ARCH)
	cp $< $@
	sed -i "/^bpf=/r seccomp/seccomp.$(ARCH)" $@
	sed -i "/^CLAUDE_SBX_BINDIR=/s:DUMMY:$(CLAUDE_BIN):" $@

seccomp/seccomp.json:
	curl -sf -o $@ https://raw.githubusercontent.com/containers/common/refs/heads/main/pkg/seccomp/seccomp.json

seccomp/seccomp.$(ARCH): seccomp/seccomp.json seccomp/seccompile
	seccomp/seccompile --machine $(ARCH) --output=- $< | zstd -19 | base64 > $@

netns-enter/netns-enter:
	@$(MAKE) -C netns-enter netns-enter

.PHONY: all clean install uninstall

clean:
	rm -f claude
	@$(MAKE) -C netns-enter clean

install: claude netns-enter/netns-enter etc/sysctl.d/99-claude-code-sandbox.conf
	install -m 0755 -t /usr/local/bin claude
	install -o root -g root -m 4755 -t /usr/local/bin netns-enter/netns-enter
	install -D -m 0644 -t /usr/local/lib/sysctl.d etc/sysctl.d/99-claude-code-sandbox.conf

uninstall:
	rm -f /usr/local/bin/claude
	rm -f /usr/local/bin/netns-enter
	rm -f /usr/local/lib/sysctl.d/99-claude-code-sandbox.conf
