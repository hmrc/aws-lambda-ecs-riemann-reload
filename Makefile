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

check_poetry: check_python
	@echo '********** Checking for poetry installation *********'
    ifeq ('$(POETRY_OK)','')
	    $(error package 'poetry' not found!)
    else
	    @echo Found poetry!
    endif

check_python: ## Check Python installation
	@echo '*********** Checking for Python installation ***********'
    ifeq ('$(PYTHON_OK)','')
	    $(error python interpreter: 'python' not found!)
    else
	    @echo Found Python
    endif
	@echo '*********** Checking for Python version ***********'
    ifneq ('$(PYTHON_REQUIRED)','$(PYTHON_VERSION)')
	    $(error incorrect version of python found: '${PYTHON_VERSION}'. Expected '${PYTHON_REQUIRED}'!)
    else
	    @echo Found Python ${PYTHON_REQUIRED}
    endif

reset: ## Teardown tooling
	rm $(poetry env info --path) -r
.PHONY: reset

setup: check_poetry ## Setup virtualenv & dependencies using poetry
	@echo '**************** Creating virtualenv *******************'
	@echo 'POETRY_VIRTUALENVS_IN_PROJECT $(POETRY_VIRTUALENVS_IN_PROJECT)'
	export POETRY_VIRTUALENVS_IN_PROJECT=$(POETRY_VIRTUALENVS_IN_PROJECT)
	poetry install --no-root
	@echo '*************** Installation Complete ******************'

bandit: setup ## Run bandit against environment_builder python code (ignoring low severity)
	poetry run bandit -ll ./tools/environment_builder/*.py --exclude tools/environment_builder/test_environment_builder.py

black: setup ## Run black against environment_builder python code
	poetry run black ./tools/environment_builder/*.py

package:
	@mkdir -p build/deps
	@poetry export -f requirements.txt --without-hashes -o build/deps/requirements.txt
	@pip install --target build/deps -r build/deps/requirements.txt
	@mkdir -p build/artifacts
	@zip -r build/artifacts/${LAMBDA_NAME}.zip ecs_riemann_reload
	@cd build/deps && zip -r ../artifacts/${LAMBDA_NAME}.zip . && cd -
	@openssl dgst -sha256 -binary build/artifacts/${LAMBDA_NAME}.zip | openssl enc -base64 > build/artifacts/${LAMBDA_NAME}.zip.base64sha256
.PHONY: package

publish:
	@if [ "$$(aws sts get-caller-identity | jq -r .Account)" != "${TELEMETRY_INTERNAL_BASE_ACCOUNT_ID}" ]; then \
  		echo "Please make sure that you execute this target with a \"telemetry-internal-base\" AWS profile. Exiting."; exit 1; fi
	aws s3 cp build/artifacts/${LAMBDA_NAME}.zip s3://${BUCKET_NAME}/build-ecs-riemann-reload-lambda/${LAMBDA_NAME}.zip --acl=bucket-owner-full-control
	aws s3 cp build/artifacts/${LAMBDA_NAME}.zip.base64sha256 s3://${BUCKET_NAME}/build-ecs-riemann-reload-lambda/${LAMBDA_NAME}.zip.base64sha256 --content-type text/plain --acl=bucket-owner-full-control
.PHONY: publish

unittest: ## Run unit tests
	@poetry run task unittest
.PHONY: unittest
