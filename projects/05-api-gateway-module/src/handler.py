"""
handler.py - Lambda handler for Project 2.3

Demonstrates the API Gateway v2 payload format (version 2.0).
The event shape differs slightly from REST API (v1) — notably
`event['requestContext']['http']['method']` instead of `event['httpMethod']`.
"""

import json
import os


def handler(event, context):
    """
    Handles all routes: GET /hello, GET /items, POST /items
    In a real app you'd split these into separate functions or use
    a router library. Here they're combined for simplicity.
    """
    method = event.get("requestContext", {}).get("http", {}).get("method", "UNKNOWN")
    path   = event.get("requestContext", {}).get("http", {}).get("path", "/")
    stage  = os.environ.get("STAGE", "unknown")

    # Route: GET /hello
    if method == "GET" and path == "/hello":
        return _response(200, {
            "message": "Hello from API Gateway + Lambda!",
            "stage": stage,
        })

    # Route: GET /items
    if method == "GET" and path == "/items":
        return _response(200, {
            "items": ["widget", "gadget", "thingamajig"],
            "stage": stage,
        })

    # Route: POST /items
    if method == "POST" and path == "/items":
        body = {}
        if event.get("body"):
            try:
                body = json.loads(event["body"])
            except json.JSONDecodeError:
                return _response(400, {"error": "Invalid JSON body"})

        return _response(201, {
            "message": "Item created (not really — this is a demo)",
            "received": body,
            "stage": stage,
        })

    # Catch-all
    return _response(404, {
        "error": f"No handler for {method} {path}"
    })


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
