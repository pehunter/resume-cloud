terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_budgets_budget" "test" {
  name              = "test-budget"
  budget_type       = "COST"
  limit_amount      = "100.0"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-10-25_00:01"
}

#Bucket
variable "bucket_name" {
  type    = string
  default = "static-site-tf-19023815"
}

resource "aws_s3_bucket" "static" {
  bucket = var.bucket_name
}

locals {
  mime_types = {
    "html" = "text/html"
    "js"   = "text/javascript"
    "css"  = "text/css"
  }
}

resource "local_file" "rendered_js" {
  filename = "subbed.js"
  content = templatefile("javascript.js", {
    api_url = aws_apigatewayv2_api.api.api_endpoint
  })
}

resource "aws_s3_object" "files" {
  for_each = fileset("static_files/", "*")

  bucket = var.bucket_name
  key    = each.value
  source = "static_files/${each.value}"
  etag   = filemd5("static_files/${each.value}")

  content_type = lookup(local.mime_types, element(split(".", each.value), length(split(".", each.value)) - 1), "text/html")

  depends_on = [aws_s3_bucket.static]
}

resource "aws_s3_object" "js_template" {
  bucket = var.bucket_name
  key    = "javascript.js"
  source = local_file.rendered_js.filename
  etag   = filemd5(local_file.rendered_js.filename)

  content_type = "text/javascript"
  depends_on   = [local_file.rendered_js, aws_s3_bucket.static]
}

#Bucket policy
data "aws_iam_policy_document" "static-bucket-policy" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.static.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.static-s3-distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow-cloudfront" {
  bucket = aws_s3_bucket.static.bucket
  policy = data.aws_iam_policy_document.static-bucket-policy.json
}

#Cloudfront
variable "s3_origin_id" {
  type    = string
  default = "myS3Origin"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "static-s3-distribution" {
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = var.s3_origin_id
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = var.s3_origin_id
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }
}

#API

resource "aws_apigatewayv2_api" "api" {
  name          = "static-site"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_headers = ["GET"]
  }
}

resource "aws_apigatewayv2_route" "visitor" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.api-lambda-integration.id}"
}

resource "aws_apigatewayv2_integration" "api-lambda-integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  description        = "When visited, increments website visitor count"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.visitor-count.invoke_arn

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_stage" "api-default-stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  # deployment_id = aws_apigatewayv2_deployment.api-deploy.id
}

# resource "aws_apigatewayv2_deployment" "api-deploy" {
#   api_id      = aws_apigatewayv2_api.api.id
#   description = "default"

#   triggers = {
#     redeployment = sha1(join(",", tolist([
#       jsonencode(aws_apigatewayv2_integration.api-lambda-integration),
#       jsonencode(aws_apigatewayv2_route.visitor),
#     ])))
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

#Lambda

#Policy: allow invoke from API
data "aws_iam_policy_document" "lambda-api-policy" {
  statement {
    sid    = "AllowsAPIGatewayInvoke"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["lambda:InvokeFunction"]

    resources = [aws_lambda_function.visitor-count.arn]

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["${aws_apigatewayv2_api.api.execution_arn}/*/*/visitor"]
    }
  }
}

resource "aws_lambda_resource_policy" "lambda-api-trigger" {
  resource_arn = aws_lambda_function.visitor-count.arn
  policy       = data.aws_iam_policy_document.lambda-api-policy.json
}

#Policy: permissions lambda function needs
data "aws_iam_policy_document" "lambda-exec-policy" {
  statement {
    sid    = "LambdaExecPolicy"
    effect = "Allow"

    actions = [
      "dynamodb:CreateTable",
      "dynamodb:ListTables",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]

    resources = [aws_dynamodb_table.visitor-ct-table.arn]
  }
}

#Lambda role setup
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "lambda-role" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda-exec-role-perms" {
  name = "lambda-exec-perms"
  role = aws_iam_role.lambda-role.id

  policy = data.aws_iam_policy_document.lambda-exec-policy.json
}


#Bundle executable
data "archive_file" "lambda-archive" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "visitor-count" {
  filename      = data.archive_file.lambda-archive.output_path
  function_name = "inc-visitors"
  role          = aws_iam_role.lambda-role.arn
  handler       = "lambda.lambda_handler"
  code_sha256   = data.archive_file.lambda-archive.output_base64sha256

  runtime = "python3.12"
}

#DynamoDB
resource "aws_dynamodb_table" "visitor-ct-table" {
  name           = "static-site-db"
  billing_mode   = "PROVISIONED"
  read_capacity  = 4
  write_capacity = 4
  hash_key       = "visitorKey"

  attribute {
    name = "visitorKey"
    type = "S"
  }

  tags = {
    Name        = "visitor-ct-table"
    Environment = "production"
  }
}
