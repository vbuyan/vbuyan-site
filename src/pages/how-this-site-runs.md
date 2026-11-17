---
layout: ../layouts/Page.astro
title: How this site runs
description: The site is a small production system of its own. Here is its architecture, pipeline and cost.
---

> **Status:** being built. This page describes the target design and will be updated with real numbers as each part goes live.

## Architecture

- **Static site** generated with [Astro](https://astro.build) from Markdown; search by Pagefind, built at deploy time, no server.
- **Hosting:** Amazon S3 (private bucket) behind CloudFront with Origin Access Control; HTTPS by ACM; DNS in Route 53.
- **Infrastructure as code:** every AWS resource in Terraform, state in S3 with locking.
- **Delivery:** GitHub Actions builds and deploys on every push to `main`. AWS access through OIDC and a
  narrowly scoped IAM role: no long-lived access keys anywhere.
- **Checks:** link checking, HTML validation and a Lighthouse budget in CI; an external uptime check with alerts.
- **Privacy:** no tracking scripts and no cookies. Traffic numbers come from CloudFront logs.

## Cost

Target: about one or two US dollars a month plus the domain. The real bill will be published here.

## Source

The code for the site and its infrastructure will be public on [GitHub](https://github.com/vbuyan).
