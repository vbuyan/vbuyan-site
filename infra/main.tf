data "aws_caller_identity" "me" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  site    = var.enable_site ? 1 : 0
  bucket  = "vbuyan-site-${data.aws_caller_identity.me.account_id}"
  www     = "www.${var.domain}"
  aliases = [var.domain, local.www]

  # AWS managed policies, referenced by their fixed ids.
  cache_optimized  = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  security_headers = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
}

# ---------------------------------------------------------------- phase 1: DNS zone

resource "aws_route53_zone" "site" {
  name    = var.domain
  comment = "vbuyan.com, managed by Terraform"
}

# ---------------------------------------------------------------- phase 2: the site

resource "aws_s3_bucket" "site" {
  count  = local.site
  bucket = local.bucket
}

resource "aws_s3_bucket_public_access_block" "site" {
  count                   = local.site
  bucket                  = aws_s3_bucket.site[0].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  count  = local.site
  bucket = aws_s3_bucket.site[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_acm_certificate" "site" {
  count                     = local.site
  domain_name               = var.domain
  subject_alternative_names = [local.www]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_site ? {
    for o in aws_acm_certificate.site[0].domain_validation_options : o.domain_name => o
  } : {}

  zone_id         = aws_route53_zone.site.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  count                   = local.site
  certificate_arn         = aws_acm_certificate.site[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_cloudfront_origin_access_control" "site" {
  count                             = local.site
  name                              = "vbuyan-site"
  description                       = "Only CloudFront may read the site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# www -> apex, "/dir/" -> "/dir/index.html", "/dir" -> "/dir/"
resource "aws_cloudfront_function" "router" {
  count   = local.site
  name    = "vbuyan-site-router"
  runtime = "cloudfront-js-2.0"
  comment = "Canonical host and directory index"
  publish = true
  code    = file("${path.module}/router.js")
}

resource "aws_cloudfront_distribution" "site" {
  count               = local.site
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "vbuyan.com"
  aliases             = local.aliases
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.site[0].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site[0].id
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cache_optimized
    response_headers_policy_id = local.security_headers

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.router[0].arn
    }
  }

  # A private bucket answers 403 for a missing key; show the site's 404 page instead.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "bucket" {
  count = local.site
  statement {
    sid       = "CloudFrontReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site[0].arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  count      = local.site
  bucket     = aws_s3_bucket.site[0].id
  policy     = data.aws_iam_policy_document.bucket[0].json
  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_route53_record" "alias" {
  for_each = var.enable_site ? {
    for pair in setproduct(local.aliases, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] }
  } : {}

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.site[0].domain_name
    zone_id                = aws_cloudfront_distribution.site[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------- deploy role for CI

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  count                = local.site
  name                 = "vbuyan-site-deploy"
  description          = "GitHub Actions: upload the built site and invalidate the CDN. Nothing else."
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  count = local.site
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site[0].arn]
  }
  statement {
    sid       = "WriteObjects"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site[0].arn}/*"]
  }
  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site[0].arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  count  = local.site
  name   = "deploy"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy[0].json
}

# ---------------------------------------------------------------- cost guard

resource "aws_budgets_budget" "monthly" {
  count        = var.budget_email == "" ? 0 : 1
  name         = "vbuyan-site-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
