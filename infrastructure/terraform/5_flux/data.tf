data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket  = "takehome-prod-terraform-state"
    key     = "eks/terraform.tfstate"
    region  = "eu-west-1"
    profile = "takehome"
  }
}
