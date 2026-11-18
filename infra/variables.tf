variable "domain" {
  description = "Apex domain of the site."
  type        = string
  default     = "vbuyan.com"
}

variable "github_repo" {
  description = "Repository whose main branch may deploy the site."
  type        = string
  default     = "vbuyan/vbuyan-site"
}

variable "enable_site" {
  description = <<-EOT
    Phase switch. false: only the DNS zone (so the registrar can be pointed at it).
    true: certificate, bucket, CDN and records. The certificate is validated through DNS,
    so this must stay false until the registrar uses the zone's name servers.
  EOT
  type        = bool
  default     = false
}

variable "budget_email" {
  description = "Where the monthly budget alert goes. Empty disables the budget. Passed from a CI secret, never committed."
  type        = string
  default     = ""
  sensitive   = true
}

variable "budget_usd" {
  description = "Monthly budget limit in USD."
  type        = number
  default     = 5
}
