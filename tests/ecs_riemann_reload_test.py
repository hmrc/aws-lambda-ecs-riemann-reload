import pytest
from moto import mock_ecs
from ecs_riemann_reload import *
from aws_lambda_context import LambdaContext


def test_it_creates_a_logger_with_a_custom_log_level():
    logger = create_logger(logging.CRITICAL)
    assert isinstance(logger, logging.Logger)
    assert logging.CRITICAL == logger.level


@mock_ecs
def test_that_the_lambda_handler_succeeds_with_context(sns_event):
    lambda_context = LambdaContext()
    lambda_context.function_name = 'lambda_handler'
    lambda_context.aws_request_id = 'abc-123'

    ecs_client = boto3.client('ecs')
    ecs_client.create_cluster(clusterName=ECS_CLUSTER_NAME)
    ecs_client.create_service(cluster=ECS_CLUSTER_NAME, serviceName=RIEMANN_CONSUMER_ECS_SERVICE_NAME)

    response = lambda_handler(event=sns_event, context=lambda_context)

    assert response['success'] is True
    assert response['serviceName'] == RIEMANN_CONSUMER_ECS_SERVICE_NAME
    assert response['status'] == "ACTIVE"


@mock_ecs
def test_that_the_lambda_handler_succeeds_without_context(sns_event):
    ecs_client = boto3.client('ecs')
    ecs_client.create_cluster(clusterName=ECS_CLUSTER_NAME)
    ecs_client.create_service(cluster=ECS_CLUSTER_NAME, serviceName=RIEMANN_CONSUMER_ECS_SERVICE_NAME)

    response = lambda_handler(event=sns_event, context=None)

    assert response['success'] is True
    assert response['serviceName'] == RIEMANN_CONSUMER_ECS_SERVICE_NAME
    assert response['status'] == "ACTIVE"


@mock_ecs
def test_that_the_lambda_handler_fails_when_providing_an_invalid_ecs_service(sns_event):
    ecs_client = boto3.client('ecs')
    ecs_client.create_cluster(clusterName=ECS_CLUSTER_NAME)
    ecs_client.create_service(cluster=ECS_CLUSTER_NAME, serviceName="not-a-riemann-service-name")

    response = lambda_handler(event=sns_event, context=None)

    assert response['success'] is False
    assert "ServiceNotFoundException" in response['errorMessage']


@pytest.fixture
def sns_event():
    return {
      "Records": [
        {
          "EventVersion": "1.0",
          "EventSubscriptionArn": "arn:aws:sns:us-east-2:123456789012:sns-lambda:21be56ed-a058-49f5-8c98-aedd2564c486",
          "EventSource": "aws:sns",
          "Sns": {
            "SignatureVersion": "1",
            "Timestamp": "2019-01-02T12:45:07.000Z",
            "Signature": "tcc6faL2yUC6dgZdmrwh1Y4cGa/ebXEkAi6RibDsvpi+tE/1+82j...65r==",
            "SigningCertUrl": "https://sns.us-east-2.amazonaws.com/SimpleNotificationService-ac565b8b1a6c5d002d285f9598aa1d9b.pem",
            "MessageId": "95df01b4-ee98-5cb9-9903-4c221d41eb5e",
            "Message": "Hello from SNS!",
            "MessageAttributes": {
              "Test": {
                "Type": "String",
                "Value": "TestString"
              },
              "TestBinary": {
                "Type": "Binary",
                "Value": "TestBinary"
              }
            },
            "Type": "Notification",
            "UnsubscribeUrl": "https://sns.us-east-2.amazonaws.com/?Action=Unsubscribe&amp;SubscriptionArn=arn:aws:sns:us-east-2:123456789012:test-lambda:21be56ed-a058-49f5-8c98-aedd2564c486",
            "TopicArn": "arn:aws:sns:us-east-2:123456789012:sns-lambda",
            "Subject": "TestInvoke"
          }
        }
      ]
    }