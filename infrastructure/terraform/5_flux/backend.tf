terraform {
  required_version = ">= 0.12.2"

  backend "s3" {
    region         = "eu-west-1"
    bucket         = "takehome-prod-terraform-state"
    key            = "flux/terraform.tfstate"
    dynamodb_table = "takehome-prod-terraform-state-lock"
    profile        = "takehome"
    role_arn       = ""
    encrypt        = "true"
  }
}
