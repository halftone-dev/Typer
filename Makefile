APP_NAME = typer
BUILD ?= `git rev-parse --short HEAD`
SHELL := /bin/bash

.PHONY: help
help: ## Show help info
	@echo "$(APP_NAME):$(BUILD)"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# To install swiftformat, run `brew install swiftformat`
.PHONY: format
format: ## Format code
	swiftformat .
