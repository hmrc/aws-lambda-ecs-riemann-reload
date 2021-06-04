#!/usr/bin/env groovy
node {
  withCredentials(
      [[$class: 'UsernamePasswordMultiBinding',
        credentialsId: 'hmrc-githubcom-service-infra-user-and-pat',
        usernameVariable: 'GIT_USERNAME',
        passwordVariable: 'GIT_PERSONAL_ACCESS_TOKEN'
      ]]
    ) {
    stage('git checkout') {
      step([$class: 'WsCleanup'])
      final scmVars = checkout(
        [$class: 'GitSCM',
         branches: [[name: '*/main']],
         doGenerateSubmoduleConfigurations: false,
         extensions: [
           [$class: 'CloneOption',
           depth: 0,
           noTags: false,
           reference: '',
           shallow: false,
           localBranch: '**']],
         userRemoteConfigs: [
           [credentialsId: 'hmrc-githubcom-service-infra-user-and-pat',
            url: 'https://github.com/hmrc/aws-lambda-ecs-riemann-reload.git']]]
      )
      sh('''#!/usr/bin/env bash
            set -ue
            echo ${scmVars.GIT_BRANCH} | cut -f 2 -d '/' > .git/_branch''')
    }
    stage('Build Poetry Docker Image') {
      sh("""#!/usr/bin/env bash
            set -ue
            ./bin/build-docker-image.sh""")
    }
    stage('Prepare Python Environment') {
      sh("""#!/usr/bin/env bash
            set -ue
            ./bin/run-in-docker.sh poetry install""")
    }
    stage('Verify (Run tests, lint, check vulnerabilities etc)') {
      sh("""#!/usr/bin/env bash
            # Don't set -e as verify will return a non zero exit code in case of vulnerabilities.
            set -u
            SKIP_FUNCTEST=true ./bin/run-in-docker.sh poetry run task verify""")
    }
    stage('Determine Artefact Version') {
      when {
        branch 'main'
      }
      sh('''#!/usr/bin/env bash
            set -ue
            GIT_BRANCH="$(cat .git/_branch)" \
            GITHUB_API_USER="${GIT_USERNAME}" \
            GITHUB_API_TOKEN="${GIT_PERSONAL_ACCESS_TOKEN}" \
            ./bin/run-in-docker.sh poetry run task prepare_release''')
    }
    stage('Build Artefact') {
      when {
        branch 'main'
      }
      sh('''#!/usr/bin/env bash
            set -ue
            SAM_USE_CONTAINER="" \
            ./bin/run-in-docker.sh poetry run task assemble''')
    }

    publishStages = ["integration",
                     "development",
                     "qa",
                     "staging",
                     "externaltest",
                     "production"].each { environmentName ->
      stage("Publish Artefact to ${environmentName} S3 Artefact Bucket") {
        when {
          branch 'main'
        }
        sh("""#!/usr/bin/env bash
              set -ue
              GIT_BRANCH="\$(cat .git/_branch)" \
              GITHUB_API_USER="\${GIT_USERNAME}" \
              GITHUB_API_TOKEN="\${GIT_PERSONAL_ACCESS_TOKEN}" \
              MDTP_ENVIRONMENT=${environmentName} \
              SAM_USE_CONTAINER="" \
              ./bin/run-in-docker.sh poetry run task publish""")
      }
    }

    stage('Create and push release tag') {
      when {
        branch 'main'
      }
      sh('''#!/usr/bin/env bash
            set -ue
            ./bin/run-in-docker.sh poetry run task cut_release''')
    }
  }
}
