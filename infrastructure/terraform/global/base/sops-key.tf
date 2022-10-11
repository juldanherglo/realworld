resource "aws_kms_key" "sops" {
  description             = "sops"
  deletion_window_in_days = 7
}
