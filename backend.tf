resource "aws_s3_bucket" "infra-bucket" {
  bucket = "terraform-bucket-inmyhead"
}

resource "aws_s3_bucket_versioning" "infra-bucket" {
  bucket = aws_s3_bucket.infra-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "infra-bucket" {
  bucket = aws_s3_bucket.infra-bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "infra-bucket" {
  bucket                  = aws_s3_bucket.infra-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
