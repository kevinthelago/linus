# linus — root Makefile
# Thin dispatcher: all build targets live in mk/*.mk.
# Add a mk/<stream>.mk file to contribute targets; do not add targets here.

MAKEFLAGS += --no-print-directory

-include mk/*.mk

.DEFAULT_GOAL := help

.PHONY: help
help: ## List available make targets
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
