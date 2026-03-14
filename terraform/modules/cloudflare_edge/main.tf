locals {
  access_include_rules = concat(
    [
      for domain in var.access_allowed_email_domains : {
        email_domain = {
          domain = startswith(domain, "@") ? domain : "@${domain}"
        }
      }
    ],
    [
      for email in var.access_allowed_emails : {
        email = {
          email = email
        }
      }
    ]
  )
}

resource "cloudflare_dns_record" "application" {
  zone_id = var.zone_id
  name    = var.public_hostname
  content = var.origin_hostname
  type    = "CNAME"
  ttl     = 1
  proxied = var.proxied
}

resource "cloudflare_zero_trust_access_policy" "allow" {
  count = var.zero_trust_enabled ? 1 : 0

  account_id = var.account_id
  name       = var.access_policy_name
  decision   = "allow"
  include    = local.access_include_rules
}

resource "cloudflare_zero_trust_access_application" "application" {
  count = var.zero_trust_enabled ? 1 : 0

  account_id                = var.account_id
  name                      = var.access_application_name
  type                      = "self_hosted"
  domain                    = var.public_hostname
  app_launcher_visible      = var.access_app_launcher_visible
  auto_redirect_to_identity = var.access_auto_redirect_to_identity
  session_duration          = var.access_session_duration
  allowed_idps              = length(var.access_allowed_identity_provider_ids) > 0 ? var.access_allowed_identity_provider_ids : null

  policies = [{
    id         = cloudflare_zero_trust_access_policy.allow[0].id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_organization" "this" {
  count = var.zero_trust_enabled && var.manage_zero_trust_organization ? 1 : 0

  account_id                 = var.account_id
  name                       = var.zero_trust_organization_name
  auth_domain                = var.zero_trust_auth_domain
  is_ui_read_only            = var.zero_trust_is_ui_read_only
  session_duration           = var.zero_trust_session_duration
  ui_read_only_toggle_reason = var.zero_trust_ui_read_only_toggle_reason
}
