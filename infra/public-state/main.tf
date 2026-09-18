# #########################################################################
# 1. 테라폼 실행 환경 설정 블록
# =========================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = "ap-southeast-2"
}

# #########################################################################
# 2. 상태 파일 저장(공유)을 위한 버킷 생성 및 버전 활성화
# =========================================================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = "std08-s3-state-bucket"

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "std08-s3-state-bucket" }
}
# 버킷 버전 관리 활성화(상태 복구용)
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# #########################################################################
# 3. 상태 잠금용 DynamoDB Table 생성
# =========================================================================
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "std08-terraform-lock-table"
  billing_mode   = "PROVISIONED"
  hash_key       = "LockID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}
