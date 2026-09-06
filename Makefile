# Where is claude?
CLAUDE_BIN := /opt/claude/bin

claude: claude.in
	cp $< $@
	sed -i "/^CLAUDE_SBX_BINDIR=/s:DUMMY:$(CLAUDE_BIN):" $@

.PHONY: clean install uninstall

clean:
	rm -f claude

install: claude
	install -m 0755 -t /usr/local/bin claude

uninstall:
	rm -f /usr/local/bin/claude
