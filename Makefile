# Where is claude?
CLAUDE_BIN := /opt/claude/bin

# Seccomp filters are arch-dependent
ARCH := $(shell uname -m)

claude: claude.in seccomp/seccomp.$(ARCH)
	cp $< $@
	sed -i "/^bpf=/r seccomp/seccomp.$(ARCH)" $@
	sed -i "/^CLAUDE_SBX_BINDIR=/s:DUMMY:$(CLAUDE_BIN):" $@

seccomp/seccomp.json:
	curl -sf -o $@ https://raw.githubusercontent.com/containers/common/refs/heads/main/pkg/seccomp/seccomp.json

seccomp/seccomp.$(ARCH): seccomp/seccomp.json seccomp/seccompile
	seccomp/seccompile --machine $(ARCH) --output=- $< | zstd -19 | base64 > $@

.PHONY: clean install uninstall

clean:
	rm -f claude

install: claude
	install -m 0755 -t /usr/local/bin claude

uninstall:
	rm -f /usr/local/bin/claude
