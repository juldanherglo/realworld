# https://github.com/cloudposse/terraform-aws-tfstate-backend#usage
#tfsec:ignore:aws-s3-block-public-acls
#tfsec:ignore:aws-s3-block-public-policy
#tfsec:ignore:aws-s3-ignore-public-acls
#tfsec:ignore:aws-s3-no-public-buckets
#tfsec:ignore:aws-sqs-enable-queue-encryption
#tfsec:ignore:aws-s3-encryption-customer-key
#tfsec:ignore:aws-dynamodb-enable-at-rest-encryption
#tfsec:ignore:aws-s3-enable-bucket-logging
#tfsec:ignore:aws-s3-specify-public-access-block
#tfsec:ignore:aws-dynamodb-table-customer-key
module "terraform_state_backend" {
  source = "cloudposse/tfstate-backend/aws"
  # Cloud Posse recommends pinning every module to a specific version
  version    = "0.38.1"
  namespace  = "takehome"
  stage      = "prod"
  name       = "terraform"
  attributes = ["state"]
  profile    = "takehome"

  terraform_backend_config_file_path = "."
  terraform_backend_config_file_name = "backend.tf"
  force_destroy                      = false
}

#tfsec:ignore:aws-kms-auto-rotate-keys
resource "aws_kms_key" "sops" {
  description             = "sops"
  deletion_window_in_days = 7
}


provider "github" {
  owner = var.github_owner
  token = data.sops_file.secrets_enc_yaml.data["github_token"]
}

resource "github_actions_secret" "renovate_secret" {
  repository      = var.repository_name
  secret_name     = "RENOVATE_TOKEN"
  plaintext_value = data.sops_file.secrets_enc_yaml.data["github_token"]
}
