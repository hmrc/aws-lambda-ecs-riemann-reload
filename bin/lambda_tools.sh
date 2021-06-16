#!/usr/bin/env bash

# A helper tool to assist us maintaining this lambda function
# Intention here is to keep all the functions reusable for all Telemetry repositories,
#   and keep the required changes between different repositories, limited to the configurations section bellow.

set -o errexit
set -o nounset

#####################################################################
## Beginning of the configurations ##################################

BUILD_NAME="build-lambda-trigger-codebuild"
FUNCTION_NAME="trigger-codebuild"
BUILD_TERRAFORM_NAME="build-telemetry-internal-base-terraform"
ARTIFACTS_NAME="trigger_codebuild"
HANDLER_FILE="handler.py"
SRC_FOLDER="src"

ARTIFACTS_ZIP_FILE="${ARTIFACTS_NAME}.zip"
ARTIFACTS_HASH_FILE="${ARTIFACTS_NAME}.zip.base64sha256"

PATH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH_SRC="${PATH_ROOT}/${SRC_FOLDER}"
PATH_HANDLER="${PATH_SRC}/${HANDLER_FILE}"
PATH_BUILD="build"
PATH_ARTIFACTS="${PATH_BUILD}/artifacts"
PATH_DEPENDENCIES="${PATH_BUILD}/dependencies"

PATH_ARTIFACTS_ZIP_FILE="${PATH_ARTIFACTS}/${ARTIFACTS_ZIP_FILE}"
PATH_ARTIFACTS_HASH_FILE="${PATH_ARTIFACTS}/${ARTIFACTS_HASH_FILE}"

S3_TELEMETRY_LAMBDA_ROOT="telemetry-lambda-artifacts-internal-base"
S3_LAMBDA_SUB_FOLDER="build-trigger-codebuild"
S3_ADDRESS="s3://${S3_TELEMETRY_LAMBDA_ROOT}/${S3_LAMBDA_SUB_FOLDER}"

## End of the configurations ########################################
#####################################################################

main() {
  # Validate command arguments
  [ "$#" -ne 1 ] && help && exit 1
  function="$1"
  functions="package push help invoke_test codebuild codebuild_lambda codebuild_master assemble publish_s3 rename_s3_file publish check_version publish_checksum_file"
  [[ $functions =~ (^|[[:space:]])"$function"($|[[:space:]]) ]] || (echo -e "\n\"$function\" is not a valid command. Try \"$0 help\" for more details" && exit 2)

  $function
}

assemble() {
  mkdir -p ${PATH_BUILD}
  poetry export --without-hashes --format requirements.txt --output ${PATH_BUILD}/requirements.txt
  SAM_CLI_TELEMETRY=0 sam build ${SAM_USE_CONTAINER:=""} --template-file resources/aws-sam-cli/template.yaml --manifest ${PATH_BUILD}/requirements.txt --region eu-west-2
}

check_version() {
  if [ ! -f ".version" ]; then
    echo "No version set, cannot publish. Please run prepare_release task."
    exit 1
  fi
}

publish() {
  assemble
  echo "start publish s3"
  publish_s3
  echo "start rename_s3_file"
  rename_s3_file
  echo "start publish_checksum_file"
  publish_checksum_file
  echo "Finished"
}

publish_checksum_file() {
  check_version
  export VERSION=$(cat .version)
  export S3_BUCKET=$(grep S3Bucket build/ecs-riemann-reload-cf-template.yaml |
    cut -d : -f 2 |
    sed 's/\s*//g')
  export S3_KEY_FOLDER=$(grep S3Key build/ecs-riemann-reload-cf-template.yaml |
    cut -d : -f 2 |
    cut -d / -f 1 | sed 's/\s*//g')
  export FILE_NAME="aws-lambda-ecs-riemann-reload.${VERSION}.zip"
  export HASH_FILE_NAME="${FILE_NAME}.base64sha256.txt"
  aws s3 cp s3://${S3_BUCKET}/${S3_KEY_FOLDER}/${FILE_NAME} build/${FILE_NAME}
  echo -n "build/${FILE_NAME}" | openssl dgst -binary -sha1 | openssl base64 >build/${HASH_FILE_NAME}
  aws s3 cp --content-type text/plain build/${HASH_FILE_NAME} s3://${S3_BUCKET}/${S3_KEY_FOLDER}/${HASH_FILE_NAME} --acl=bucket-owner-full-control
}

publish_s3() {
  check_version

  # Unfortunately Poetry won't allow
  # us to add awscli to the --dev dependencies due to transitive
  # dependency conflicts with aws-sam-cli. Until the conflicts are
  # resolved we have to use pip to install awscli.
  pip install awscli

  SAM_CLI_TELEMETRY=0 sam package ${SAM_USE_CONTAINER:=""} --region eu-west-2 \
    --s3-bucket telemetry-lambda-artifacts-internal-base \
    --s3-prefix build-aws-lambda-ecs-riemann-reload \
    --output-template-file=$(pwd)/build/ecs-riemann-reload-cf-template.yaml
}

rename_s3_file() {
  check_version
  export VERSION=$(cat .version)
  export S3_BUCKET=$(grep S3Bucket build/ecs-riemann-reload-cf-template.yaml |
    cut -d : -f 2 |
    sed 's/\s*//g')
  export S3_KEY_FOLDER=$(grep S3Key build/ecs-riemann-reload-cf-template.yaml |
    cut -d : -f 2 |
    cut -d / -f 1 | sed 's/\s*//g')
  export S3_KEY_FILENAME=$(grep S3Key build/ecs-riemann-reload-cf-template.yaml |
    cut -d : -f 2 |
    cut -d / -f 2 | sed 's/\s*//g')
  aws s3 cp s3://${S3_BUCKET}/${S3_KEY_FOLDER}/${S3_KEY_FILENAME} \
    s3://${S3_BUCKET}/${S3_KEY_FOLDER}/aws-lambda-ecs-riemann-reload.${VERSION}.zip \
    --content-type text/plain --acl=bucket-owner-full-control
}

help() {
  echo "$0 Provides set of commands to assist you with day-to-day tasks when working in this project"
  echo
  echo "Available commands:"
  echo -e " - assemble\t\tUse SAM to build your Lambda function code"
  echo -e " - codebuild\t\tTrigger the AWS CodeBuild '${BUILD_NAME}' from the current branch in internal-base"
  echo -e " - codebuild_lambda\tTrigger the AWS CodeBuild '${BUILD_TERRAFORM_NAME}' in internal-base.\n\t\t\t (this only targets the '${FUNCTION_NAME}' lambda function)"
  echo -e " - codebuild_master\tTrigger the AWS CodeBuild '${BUILD_NAME}' in internal-base"
  echo -e " - invoke_test\t\tInvoke ${FUNCTION_NAME} function"
  echo -e " - package\t\tCreate a zip file and hash for it and store them under tmp/build/artifact.\n\t\t\tThe zip file contains:\n\t\t\t - The Lambda source file \n\t\t\t - Production dependencies defined under pyproject.toml's tool.poetry.dependencies section"
  echo -e " - publish_s3\t\tUses SAM to Package an AWS SAM application and upload to an S3 bucket"
  echo -e " - push\t\t\tUpload the produced artifacts by the package command to ${S3_ADDRESS}"
  echo -e " - rename_s3_file\t\t\tDuplicate artifact generated by SAM to a suitable file name"
  echo
}

main "$@"
