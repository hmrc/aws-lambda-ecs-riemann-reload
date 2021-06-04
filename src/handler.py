import boto3
import os
from aws_lambda_powertools import Logger

logger = Logger(
    service="aws-lambda-ecs-riemann-reload",
    level=os.environ.get("LOG_LEVEL", "INFO"),
)


def lambda_handler(event, context):
    try:
        logger.info(f"Lambda Request ID: {context.aws_request_id}")
    except AttributeError:
        logger.debug(f"No context object available")

    logger.info(f'Event received from SNS: "{event}"')

    ecs_client = boto3.client("ecs")

    ecs_service_name = os.environ.get(
        "riemann_consumer_ecs_service_name", "riemann-consumer"
    )
    logger.info(f"Requesting a new deployment of the ECS {ecs_service_name} service")
    try:
        response = ecs_client.update_service(
            cluster=os.environ.get("ecs_cluster_name", "telemetry"),
            service=ecs_service_name,
            forceNewDeployment=True,
        )
        logger.info(f'Deployment request completed: "{response}"')

        return {
            "success": True,
            "serviceName": response["service"]["serviceName"],
            "status": response["service"]["status"],
            "desiredCount": response["service"]["desiredCount"],
            "runningCount": response["service"]["runningCount"],
            "pendingCount": response["service"]["pendingCount"],
        }
    except Exception as e:
        logger.error(f"Deployment action failed: {e}")

        return {"success": False, "errorMessage": str(e)}
