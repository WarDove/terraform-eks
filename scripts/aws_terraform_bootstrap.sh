#!/bin/bash

# Based on:
# * https://github.com/hashicorp/terraform/issues/12877#issuecomment-311649591
# * https://www.terraform.io/docs/backends/types/s3.html

# This script creates the AWS S3 bucket and DynamoDB that Terraform needs to
# have a lockable remote state, outputs a backend config.
# You need to have terraform.tfvars configured with the aws profile.

# [-p|--prod] flag bootstraps to production environment. expects the varfile to be
# named "terraform.prod.tfvars"

set -euo pipefail

varfile="terraform.tfvars"
region="eu-central-1"
project_name="gitlab-poc"
dynamodb_table="${project_name}-terraform-locks"
s3_bucket_name="${project_name}-terraform-${region}"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--prod)
      dynamodb_table="${project_name}-terraform-prod-locks"
      s3_bucket_name="${project_name}-terraform-prod-${region}"
      varfile="terraform.prod.tfvars"
      shift
      ;;
    -s|--staging)
      dynamodb_table="${project_name}-terraform-staging-locks"
      s3_bucket_name="${project_name}-terraform-staging-${region}"
      varfile="terraform.staging.tfvars"
      shift
      ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
done

profile="$(echo 'var.profile' | terraform console -var-file ${varfile} | tr -d '\"')"
aws_account_id="$(aws sts get-caller-identity --query Account --output text --profile ${profile})"

if [[ $region != 'us-east-1' ]]; then
  aws s3api create-bucket \
    --bucket "${s3_bucket_name}" \
    --create-bucket-configuration LocationConstraint="${region}" \
    --region "${region}" \
    --profile "${profile}"
else
  aws s3api create-bucket \
    --bucket "${s3_bucket_name}" \
    --profile "${profile}"
fi

aws s3api put-bucket-versioning \
  --bucket "${s3_bucket_name}" \
  --versioning-configuration Status=Enabled \
  --profile "${profile}"

aws s3api put-bucket-encryption \
  --bucket "${s3_bucket_name}" \
  --profile "${profile}" \
  --server-side-encryption-configuration "{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}"

dynamodb_exists=$(aws dynamodb list-tables --profile "${profile}" --output json | jq -r '.TableNames[] | contains("${dynamodb_table}")')

if [[ "$dynamodb_exists" != 'true' ]]; then
  aws dynamodb create-table \
    --attribute-definitions 'AttributeName=LockID,AttributeType=S' \
    --key-schema 'AttributeName=LockID,KeyType=HASH' \
    --provisioned-throughput 'ReadCapacityUnits=1,WriteCapacityUnits=1' \
    --region "${region}" \
    --profile "${profile}" \
    --table-name "${dynamodb_table}"
fi

cat <<EOF
terraform {
  backend "s3" {
    bucket = "${s3_bucket_name}"
    encrypt = "true"
    key = "terraform.tfstate"
    dynamodb_table = "${dynamodb_table}"
    region = "${region}"
  }
}
EOF
