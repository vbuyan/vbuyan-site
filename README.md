# vbuyan.com

Personal site of Vitalii Buyan, DevOps / Site Reliability Engineer: projects, methods, postmortems and notes.

- **Site:** [Astro](https://astro.build) + [Pagefind](https://pagefind.app), Markdown pages in `src/pages`.
- **Infrastructure:** Terraform in [`infra/`](infra): private S3 bucket, CloudFront with Origin Access Control,
  ACM, Route 53, a CloudFront Function for routing, a budget alert.
- **Delivery:** GitHub Actions with OIDC, no stored AWS keys. [`site.yml`](.github/workflows/site.yml) builds and
  deploys; [`infra.yml`](.github/workflows/infra.yml) runs Terraform.

The full write-up is on the site: [How this site runs](https://vbuyan.com/how-this-site-runs/).

## Local

```bash
npm ci
npm run dev       # http://localhost:4321
npm run build     # static site + search index in dist/
```

## First-time setup (once)

1. In AWS CloudShell: `bash infra/bootstrap/bootstrap.sh` (state bucket, GitHub OIDC provider, Terraform role).
2. Repository variable `AWS_ACCOUNT_ID`; optional secret `BUDGET_EMAIL`.
3. Push: the `infra` workflow creates the Route 53 zone and prints its name servers. Set them at the registrar.
4. Set `enable_site = true` in `infra/phase.auto.tfvars` and push: certificate, bucket, CDN, records, deploy role.
5. Repository variables `CF_DISTRIBUTION_ID` (from the outputs) and `SITE_LIVE=true`. Every push now deploys.
