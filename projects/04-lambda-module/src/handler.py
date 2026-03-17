"""
handler.py - Sample Lambda function for Project 2.2

This function is intentionally simple — just enough to prove the Lambda
module works end-to-end. It reads an environment variable and returns
a JSON response, which you can verify in the Lambda console test tab.
"""

import json
import os


def handler(event, context):
    greeting = os.environ.get("GREETINGS", "Hello")
    stage = os.environ.get("STAGE", "unknown")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"{greeting} from the tf-learning Lambda!",
            "stage": stage,
            "event": event,
        }),
    }
