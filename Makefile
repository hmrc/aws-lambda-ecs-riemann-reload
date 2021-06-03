SHELL := /usr/bin/env bash
POETRY_OK := $(shell type -P poetry)
PYTHON_OK := $(shell type -P python)
PYTHON_VERSION ?= $(shell python -V | cut -d' ' -f2)
PYTHON_REQUIRED := $(shell cat .python-version)
ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
POETRY_VIRTUALENVS_IN_PROJECT ?= true

TELEMETRY_INTERNAL_BASE_ACCOUNT_ID := 634456480543
BUCKET_NAME := telemetry-lambda-artifacts-internal-base
LAMBDA_NAME := ecs_riemann_reload

help: ## The help text you're reading
	@grep --no-filename -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

clean: ## Clean the environment
	@poetry run task clean
.PHONY: clean

check_poetry: check_python ## Check Poetry installation
    ifeq ('$(POETRY_OK)','')
	    $(error package 'poetry' not found!)
    else
	    @echo Found poetry!
    endif
.PHONY: check_poetry

check_python: ## Check Python installation
    ifeq ('$(PYTHON_OK)','')
	    $(error python interpreter: 'python' not found!)
    else
	    @echo Found Python
    endif
    ifneq ('$(PYTHON_REQUIRED)','$(PYTHON_VERSION)')
	    $(error incorrect version of python found: '${PYTHON_VERSION}'. Expected '${PYTHON_REQUIRED}'!)
    else
	    @echo Found Python ${PYTHON_REQUIRED}
    endif
.PHONY: check_python

reset: ## Teardown tooling
	rm $(poetry env info --path) -r
.PHONY: reset

setup: check_poetry ## Setup virtualenv & dependencies using poetry
	export POETRY_VIRTUALENVS_IN_PROJECT=$(POETRY_VIRTUALENVS_IN_PROJECT) && poetry run pip install --upgrade pip
	poetry install --no-root
.PHONY: setup

bandit: setup ## Run bandit against python code
	@poetry run task bandit
.PHONY: bandit

black: setup ## Run black against python code
	@poetry run task black_reformat
.PHONY: black

safety: setup ## Run Safety
	@poetry run task safety
.PHONY: safety

test: setup ## Run functional and unit tests
	@poetry run task test
.PHONY: test

package: setup ## Run a SAM build
	@poetry run task assemble
.PHONY: package

publish: setup ## Build and push lambda zip to S3 (requires MDTP_ENVIRONMENT to be set to an environment )
	@poetry run task publish
.PHONY: publish

unittest: ## Run unit tests
	@poetry run task unittest
.PHONY: unittest
