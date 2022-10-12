data "sops_file" "secrets_enc_yaml" {
  source_file = "secrets.enc.yaml"
}
