PREFIX ?= $(HOME)/.local
DESTDIR ?=

.PHONY: install test check

install:
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 bin/starlink "$(DESTDIR)$(PREFIX)/bin/starlink"
	install -d "$(DESTDIR)$(PREFIX)/share/bash-completion/completions"
	install -m 644 completions/starlink.bash "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/starlink"
	install -d "$(DESTDIR)$(PREFIX)/share/zsh/site-functions"
	install -m 644 completions/_starlink "$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_starlink"

test:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests

check:
	bash -n bin/starlink get_clients.sh completions/starlink.bash
