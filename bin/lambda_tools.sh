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
PATH_TMP="${PATH_ROOT}/tmp"
PATH_BUILD="${PATH_TMP}/build"
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
  functions="package push help invoke_test codebuild codebuild_lambda codebuild_master"
  [[ $functions =~ (^|[[:space:]])"$function"($|[[:space:]]) ]] || (echo -e "\n\"$function\" is not a valid command. Try \"$0 help\" for more details" && exit 2)

  $function
}

package() {
  echo "#################################################"
  echo "Beginning of package command, to create artifacts"
  pushd "${PATH_ROOT}" > /dev/null

  print_step "Tests"
  poetry run task test && print_step_done || exit 1

  print_step "Check format"
  poetry run task check && print_step_done || (echo "Black spotted formatting issue, running \"poetry run task black\" might help" && exit 1)

  print_step "Clear/prepare build folder"
  rm -rf "${PATH_DEPENDENCIES}" "${PATH_ARTIFACTS}" &&\
  mkdir -p "${PATH_DEPENDENCIES}" "${PATH_ARTIFACTS}" &&\
  print_step_done

  print_step "Create artifacts zip file and add ${SRC_FOLDER}/${HANDLER_FILE} to it"
  zip "${PATH_ARTIFACTS_ZIP_FILE}" "${SRC_FOLDER}/${HANDLER_FILE}" && print_step_done

  print_step "Preparing dependencies, this might take a bit of time"
  poetry export -f requirements.txt --without-hashes -o "${PATH_DEPENDENCIES}"/requirements.txt &&\
  poetry run pip -q install --target "${PATH_DEPENDENCIES}" -r "${PATH_DEPENDENCIES}"/requirements.txt &&\
  print_step_done
  popd > /dev/null

  print_step "Add dependencies to the artifacts zip file"
  pushd "${PATH_DEPENDENCIES}" > /dev/null
  zip -qr "${PATH_ARTIFACTS_ZIP_FILE}" . && print_step_done
  popd > /dev/null

  print_step "Generate base64 hash for the zipped artifacts"
  openssl dgst -sha256 -binary "${PATH_ARTIFACTS_ZIP_FILE}" | openssl enc -base64 >"${PATH_ARTIFACTS_HASH_FILE}" && print_step_done
  echo -e "The following artifacts have been created and ready to be pushed:"
  echo -e "  - ./${PATH_ARTIFACTS_ZIP_FILE}\n  - ./${PATH_ARTIFACTS_HASH_FILE}"
  echo -e "\npackage command completed!"
  echo -e "##########################\n\n"
}

step_counter=0
print_step() {
  step_counter=`expr $step_counter + 1`
  echo -e "\n[ ${step_counter}. $1 ]"
}

print_step_done() {
  echo -e "[ \U1F44D Step ${step_counter} completed!]\n"
}

push() {
  echo "#################################################"
  echo "Beginning of push command, to uploading artifacts"
  print_step "Upload artifacts zip file"
  aws s3 cp "${PATH_ARTIFACTS_ZIP_FILE}" ${S3_ADDRESS}/${ARTIFACTS_ZIP_FILE}\
    --acl=bucket-owner-full-control  && print_step_done
  print_step "Upload artifacts hash file"
  aws s3 cp "${PATH_ARTIFACTS_HASH_FILE}" ${S3_ADDRESS}/${ARTIFACTS_HASH_FILE}\
    --content-type text/plain --acl=bucket-owner-full-control && print_step_done
  echo -e "\npush command completed!"
  echo -e "#######################\n\n"
}

codebuild() {
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  print_step "Starting '${BUILD_NAME}' CodeBuild job from ${CURRENT_BRANCH} branch"
  aws codebuild start-build\
    --project-name ${BUILD_NAME}\
    --source-version "${CURRENT_BRANCH}"\
    --query 'build.[projectName, currentPhase, {Build: buildNumber}, {"For branch": sourceVersion}]' && print_step_done
}

codebuild_master() {
  print_step "Start '${BUILD_NAME}' CodeBuild job from master"
  aws codebuild start-build\
    --project-name ${BUILD_NAME}\
    --query 'build.[projectName, currentPhase, {Build: buildNumber}, {"For branch": sourceVersion}]' && print_step_done
}

codebuild_lambda() {
  echo "#####################################"
  echo "Beginning of codebuild_lambda command"
  print_step "Start '${BUILD_TERRAFORM_NAME}' CodeBuild job from master, targeting 'lambda-trigger-codebuild' component"
  aws codebuild start-build\
    --environment-variables-override name=COMPONENT_ROOT,value=base name=COMPONENT,value=lambda-trigger-codebuild\
    --project-name "${BUILD_TERRAFORM_NAME}"\
    --query 'build.[projectName, currentPhase, {Build: buildNumber}, {"For branch": sourceVersion}]' && print_step_done
  echo -e "\ncodebuild_lambda command completed!"
  echo -e "###################################\n\n"
}

invoke_test() {
  echo "################################"
  echo "Beginning of invoke_test command"
  outfile="${PATH_TMP}/invoke_test_response.json"
  aws lambda invoke\
    --function-name "${FUNCTION_NAME}"\
    "${outfile}" && cat tmp/invoke_test_response.json | jq .
  echo -e "\ninvoke_test command completed!"
  echo -e "##############################\n\n"
}

help() {
  echo "$0 Provides set of commands to assist you with day-to-day tasks when working in this project."
  echo
  echo "Available commands:"
  echo -e " - codebuild\t\tTrigger the AWS CodeBuild '${BUILD_NAME}' from the current branch in internal-base"
  echo -e " - codebuild_lambda\tTrigger the AWS CodeBuild '${BUILD_TERRAFORM_NAME}' in internal-base.\n\t\t\t (this only targets the '${FUNCTION_NAME}' lambda function)"
  echo -e " - codebuild_master\tTrigger the AWS CodeBuild '${BUILD_NAME}' in internal-base"
  echo -e " - invoke_test\t\tInvoke ${FUNCTION_NAME} function"
  echo -e " - package\t\tCreate a zip file and hash for it and store them under tmp/build/artifact.\n\t\t\tThe zip file contains:\n\t\t\t - The Lambda source file \n\t\t\t - Production dependencies defined under pyproject.toml's tool.poetry.dependencies section "
  echo -e " - push\t\t\tUpload the produced artifacts by the package command to ${S3_ADDRESS}"
  echo
}

main "$@"
