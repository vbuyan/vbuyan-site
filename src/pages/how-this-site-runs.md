---
layout: ../layouts/Page.astro
title: How this site runs
description: The site is a small production system of its own. Here is its architecture, pipeline, security model and cost.
---

```
git push ──► GitHub Actions ──► build (Astro + Pagefind) ──► link check
                   │
                   │  OIDC: short-lived credentials, no stored keys
                   ▼
            S3 (private bucket) ◄── read only by ── CloudFront ◄── visitors
                                                        ▲
                                    ACM certificate ────┤
                                    Route 53 (DNS) ─────┘
```

## Architecture

- **Static site** generated with [Astro](https://astro.build) from Markdown. Search is [Pagefind](https://pagefind.app),
  an index built at deploy time, so there is no server and no database.
- **Storage:** a private S3 bucket. Public access is blocked; only this CloudFront distribution may read it,
  through Origin Access Control and a bucket policy scoped to the distribution's ARN.
- **Edge:** CloudFront with HTTP/2 and HTTP/3, TLS 1.2+ with a certificate from ACM, AWS's managed security
  headers policy, and a small CloudFront Function that sends `www` to the apex domain and maps `/page/` to
  `/page/index.html`.
- **DNS:** Route 53, alias records for the apex and `www`, IPv4 and IPv6.

## Infrastructure as code

Every AWS resource is in [Terraform](https://github.com/vbuyan/vbuyan-site/tree/main/infra). State lives in a
versioned, encrypted S3 bucket with S3-native locking. Only three things are created outside Terraform, by a short
[bootstrap script](https://github.com/vbuyan/vbuyan-site/blob/main/infra/bootstrap/bootstrap.sh): the state
bucket, the GitHub OIDC provider and the role Terraform itself runs as.

The rollout has two phases on purpose. Phase one creates only the DNS zone, so the registrar can be pointed at it.
Phase two adds the certificate, which is validated through DNS and would hang if the domain still pointed elsewhere.

## Delivery

- Every push to `main` builds the site, checks internal links and uploads it. Pull requests run the same build
  without deploying.
- Infrastructure changes run `terraform fmt`, `validate`, `plan` and `apply` in their own workflow.
- **No long-lived AWS keys exist anywhere.** GitHub Actions gets temporary credentials through OIDC, and only
  the `main` branch of this repository can assume the roles. The deploy role can write to one bucket and
  invalidate one distribution, nothing else.
- Hashed assets are cached for a year; pages are revalidated on every request, so a deploy is visible at once.

## Cost

Expected: under one US dollar a month (the DNS zone is most of it) plus the domain. A budget alert fires before
the bill passes five dollars.

## Privacy

No tracking scripts, no cookies, no analytics.
