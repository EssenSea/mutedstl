# mutedstl — developer entry points.
# Run `make` (or `make help`) to list targets.

VIM      ?= vim
SHELL    := /bin/sh
VERSION  := $(shell cat VERSION 2>/dev/null || echo unknown)

.PHONY: all help test lint docs docs-check check clean

all: check

help: ## Show this help
	@echo "mutedstl $(VERSION)"
	@echo
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

test: ## Run the headless regression test suite
	@test/run.sh

lint: ## Static checks (shellcheck + help tag freshness)
	@echo "== shellcheck =="
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck test/run.sh; \
	else echo "shellcheck not installed, skipping"; fi
	@echo "== help tags up to date =="
	@$(MAKE) -s docs-check

docs: ## Regenerate doc/tags from doc/mutedstl.txt
	@$(VIM) -N -u NONE -i NONE -es -c 'helptags doc' -c 'qall!'
	@echo "doc/tags regenerated"

docs-check: ## Verify doc/tags matches the help file
	@tmp=$$(mktemp -d); cp doc/mutedstl.txt $$tmp/ ; \
	$(VIM) -N -u NONE -i NONE -es -c "helptags $$tmp" -c 'qall!' ; \
	if diff -q $$tmp/tags doc/tags >/dev/null; then \
		echo "doc/tags is up to date"; rm -rf $$tmp; \
	else \
		echo "doc/tags is STALE - run 'make docs'"; diff $$tmp/tags doc/tags; rm -rf $$tmp; exit 1; \
	fi

check: test lint ## Run all checks (used by CI)

clean: ## Remove generated artefacts
	@rm -f *.out test/*.out
	@echo "cleaned"
