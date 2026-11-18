output "name_servers" {
  description = "Set these at the registrar (Porkbun) for vbuyan.com."
  value       = aws_route53_zone.site.name_servers
}

output "bucket" {
  value = var.enable_site ? aws_s3_bucket.site[0].id : null
}

output "distribution_id" {
  value = var.enable_site ? aws_cloudfront_distribution.site[0].id : null
}

output "distribution_domain" {
  value = var.enable_site ? aws_cloudfront_distribution.site[0].domain_name : null
}

output "deploy_role_arn" {
  value = var.enable_site ? aws_iam_role.deploy[0].arn : null
}
