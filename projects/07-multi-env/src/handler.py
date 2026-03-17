"""
handler.py - Serverless API handler for Phase 3

A slightly more realistic API than the previous projects:
  GET  /          - health check
  GET  /products  - list products
  GET  /products/{id} - get a single product
  POST /products  - create a product

Products are stored in DynamoDB. The table name is injected via
the PRODUCTS_TABLE environment variable, set by Terraform.
"""

import json
import os
import uuid
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")


def handler(event, context):
    table_name = os.environ.get("PRODUCTS_TABLE")
    table = dynamodb.Table(table_name)

    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path   = event.get("requestContext", {}).get("http", {}).get("path", "/")

    try:
        # Health check
        if method == "GET" and path == "/":
            return _response(200, {"status": "healthy", "stage": os.environ.get("STAGE")})

        # List products
        if method == "GET" and path == "/products":
            result = table.scan()
            return _response(200, {"products": result.get("Items", [])})

        # Get single product
        if method == "GET" and path.startswith("/products/"):
            product_id = path.split("/products/")[1]
            result = table.get_item(Key={"id": product_id})
            item = result.get("Item")
            if not item:
                return _response(404, {"error": f"Product {product_id} not found"})
            return _response(200, {"product": item})

        # Create product
        if method == "POST" and path == "/products":
            body = json.loads(event.get("body") or "{}")
            if not body.get("name"):
                return _response(400, {"error": "name is required"})

            product = {
                "id":    str(uuid.uuid4()),
                "name":  body["name"],
                "price": body.get("price", 0),
            }
            table.put_item(Item=product)
            return _response(201, {"product": product})

        return _response(404, {"error": f"No handler for {method} {path}"})

    except Exception as e:
        print(f"ERROR: {e}")
        return _response(500, {"error": "Internal server error"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
