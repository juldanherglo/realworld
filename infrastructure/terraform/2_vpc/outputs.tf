output "vpc" {
  description = "vpc values"
  value       = module.vpc
}

output "zone" {
  description = "route53 zone values"
  value       = aws_route53_zone.private
}
