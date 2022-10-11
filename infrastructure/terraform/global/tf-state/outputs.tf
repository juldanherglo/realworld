output "sops_key_arn" {
  description = "kms arn to be used for sops"
  value       = aws_kms_key.sops.arn
}
