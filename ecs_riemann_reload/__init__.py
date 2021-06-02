import boto3
import logging
import os


def get_log_level():
    log_level = os.environ.get("log_level", "INFO")
    return log_level.upper() if isinstance(log_level, str) else log_level


def get_ecs_cluster_name():
    return os.environ.get("ecs_cluster_name", "telemetry")


def get_lambda_name():
    os.environ.get("lambda_name", "ecs-riemann-reload")


def get_riemann_consumer_ecs_service_name():
    return os.environ.get("riemann_consumer_ecs_service_name", "riemann-consumer")


def create_logger(level=logging.INFO):
    logger = logging.getLogger()
    logger.setLevel(level)

    return logger


def lambda_handler(event, context):
    logger = create_logger(get_log_level())
    try:
        logger.info(f"Lambda Request ID: {context.aws_request_id}")
    except AttributeError:
        logger.debug(f"No context object available")

    logger.info(f'Event received from SNS: "{event}"')

    ecs_client = boto3.client("ecs")

    ecs_service_name = get_riemann_consumer_ecs_service_name()
    logger.info(f"Requesting a new deployment of the ECS {ecs_service_name} service")
    try:
        response = ecs_client.update_service(
            cluster=get_ecs_cluster_name(),
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
