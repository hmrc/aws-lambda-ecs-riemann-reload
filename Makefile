SHELL := /usr/bin/env bash
ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

TELEMETRY_INTERNAL_BASE_ACCOUNT_ID := 634456480543
BUCKET_NAME := telemetry-lambda-artifacts-internal-base
LAMBDA_NAME := ecs_riemann_reload

help: ## The help text you're reading
	@grep --no-filename -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

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

test:
	@poetry run pytest --cov=ecs_riemann_reload
.PHONY: test