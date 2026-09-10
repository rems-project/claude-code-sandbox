## A few knobs for the target system:
##
## Where is claude?
CLAUDE_BIN := /opt/claude/bin
## Claude's $HOME.
CLAUDE_HOME := .claude-home
## Network namespace.
NETNS := agents

# Seccomp filters are arch-dependent
ARCH := $(shell uname -m)

all: claude claude-update netns-enter/netns-enter etc/netns-enter

claude: claude.in seccomp/seccomp.$(ARCH)
	cp $< $@
	sed -i "/^bpf=/r seccomp/seccomp.$(ARCH)" $@
	sed -i "/^CLAUDE_SBX_HOME=/s:DUMMY:$(CLAUDE_HOME):" $@
	sed -i "/^CLAUDE_SBX_BINDIR=/s:DUMMY:$(CLAUDE_BIN):" $@
	sed -i "/^CLAUDE_SBX_NETNS=/s:DUMMY:$(NETNS):" $@

seccomp/seccomp.json:
	curl -sf -o $@ https://raw.githubusercontent.com/containers/common/refs/heads/main/pkg/seccomp/seccomp.json

seccomp/seccomp.$(ARCH): seccomp/seccomp.json seccomp/seccompile
	seccomp/seccompile --machine $(ARCH) --output=- $< | zstd -19 | base64 > $@

claude-update: claude-update.in
	cp $< $@
	sed -i "/^CLAUDE_SBX_BINDIR=/s:DUMMY:$(CLAUDE_BIN):" $@

netns-enter/netns-enter:
	@$(MAKE) -C netns-enter netns-enter

etc/netns-enter: etc/netns-enter.in
	cp $< $@
	sed -i "s:DUMMY:$(NETNS):" $@

.PHONY: all clean install uninstall

clean:
	rm -f claude claude-update etc/netns-enter
	@$(MAKE) -C netns-enter clean

install: claude claude-update etc/sysctl.d/*
	install -D -m 0755 -t /usr/local/bin claude claude-update
	install -D -m 0644 -t /usr/local/lib/sysctl.d etc/sysctl.d/*

install-network: netns-enter/netns-enter etc/netns-enter etc/systemd/system/* etc/systemd/network/*
	install -D -o root -g root -m 4755 -t /usr/local/bin netns-enter/netns-enter
	install -D -m 0644 -t /usr/local/etc etc/netns-enter
	install -D -m 0644 -t /usr/local/lib/systemd/network etc/systemd/network/*
	install -D -m 0644 -t /usr/local/lib/systemd/system etc/systemd/system/*

uninstall:
	rm -f /usr/local/bin/claude
	rm -f /usr/local/bin/claude-update
	rm -f /usr/local/lib/sysctl.d/99-claude-code-sandbox.conf

uninstall-network:
	rm -f /usr/local/bin/netns-enter
	rm -f /usr/local/etc/netns-enter
	rm -f /usr/local/lib/systemd/network/br-netns.*
	rm -f /usr/local/lib/systemd/network/bridging.*
	rm -f /usr/local/lib/systemd/system/netns@.service
