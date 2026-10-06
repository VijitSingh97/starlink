PREFIX ?= $(HOME)/.local
DESTDIR ?=
BASH_COMPLETION_DIR ?= $(PREFIX)/share/bash-completion/completions
ZSH_COMPLETION_DIR ?= $(PREFIX)/share/zsh/site-functions

.PHONY: install test check lint deb grpcurl-debs packages

install:
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 bin/starlink "$(DESTDIR)$(PREFIX)/bin/starlink"
	install -d "$(DESTDIR)$(BASH_COMPLETION_DIR)"
	install -m 644 completions/starlink.bash "$(DESTDIR)$(BASH_COMPLETION_DIR)/starlink"
	install -d "$(DESTDIR)$(ZSH_COMPLETION_DIR)"
	install -m 644 completions/_starlink "$(DESTDIR)$(ZSH_COMPLETION_DIR)/_starlink"

test:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests

check:
	bash -n bin/starlink get_clients.sh completions/starlink.bash
	test "$$(bin/starlink --version)" = "starlink $$(cat VERSION)"

lint: check
	shellcheck bin/starlink get_clients.sh completions/starlink.bash scripts/*.sh

deb:
	./scripts/build-deb.sh

grpcurl-debs:
	./scripts/build-grpcurl-debs.sh

packages: deb grpcurl-debs
