import boto3
import logging

ECS_CLUSTER_NAME = "telemetry"
LAMBDA_NAME = "ecs-riemann-reload"
RIEMANN_CONSUMER_ECS_SERVICE_NAME = "riemann-consumer"


def create_logger(level=logging.INFO):
    logger = logging.getLogger()
    logger.setLevel(level)

    return logger


def lambda_handler(event, context):
    logger = create_logger(logging.DEBUG)
    try:
        logger.info(f"Lambda Request ID: {context.aws_request_id}")
    except AttributeError:
        logger.debug(f"No context object available")

    logger.info(f"Event received from SNS: \"{event}\"")

    ecs_client = boto3.client("ecs")

    ecs_service_name = RIEMANN_CONSUMER_ECS_SERVICE_NAME
    logger.info(f"Requesting a new deployment of the ECS {ecs_service_name} service")
    try:
        response = ecs_client.update_service(
            cluster=ECS_CLUSTER_NAME, service=ecs_service_name, forceNewDeployment=True
        )
        logger.info(f"Deployment request completed: \"{response}\"")

        return {
            'success': True,
            'serviceName': response['service']['serviceName'],
            'status': response['service']['status'],
            'desiredCount': response['service']['desiredCount'],
            'runningCount': response['service']['runningCount'],
            'pendingCount': response['service']['pendingCount'],
        }
    except Exception as e:
        logger.error(f"Deployment action failed: {e}")

        return {
            'success': False,
            'errorMessage': str(e)
        }
