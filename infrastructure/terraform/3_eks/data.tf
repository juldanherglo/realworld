data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = "takehome-prod-terraform-state"
    key     = "vpc/terraform.tfstate"
    region  = "eu-west-1"
    profile = "takehome"
  }
}
