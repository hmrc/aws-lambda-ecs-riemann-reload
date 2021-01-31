# telemetry-ecs-riemann-reload-lambda

[![Brought to you by Telemetry Team](https://img.shields.io/badge/MDTP-Telemetry-40D9C0?style=flat&labelColor=000000&logo=gov.uk)](https://confluence.tools.tax.service.gov.uk/display/TEL/Telemetry)

An AWS Lambda that will re-deploy the Riemann consumer or producer services running in ECS, when triggered by an SNS notification.
The SNS notification is in turn triggered by an alarm configured to look at when the Kafka agent running in Riemann is (unexpectedly) stopped.

Please check the [telemetry-terraform](https://github.com/hmrc/telemetry-terraform) repository for details on how this Lambda is deployed.

## Requirements

* [Python 3.8+](https://www.python.org/downloads/release)
* [Poetry](https://python-poetry.org/)

## Quick start

```shell
# Run tests:
$ make test

# Package the lambda locally:
$ make package

# Push the package to the lambdas bucket in telemetry-internal-base:
$ aws-profile -p telemetry-internal-base-RoleTelemetryEngineer make publish
```

### License

This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html").
