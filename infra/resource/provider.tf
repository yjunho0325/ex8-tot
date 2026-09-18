terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
  backend "s3" {
    bucket         = "std08-s3-state-bucket"
    key            = "TerraformState/EX/ex8-tot/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "std08-terraform-lock-table"
    encrypt        = true
  }
}
provider "aws" {
  region = "ap-southeast-2"

  # 기본 태그 설정: 태라폼으로 생성한 리소스들에 추가
  default_tags {
    tags = local.common_tags
  }
}
