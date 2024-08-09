variable "aws_region" {
  default = "eu-north-1"
}

variable "vault_addr" {
  type        = string
  description = "The address of the Vault server. If using HCP Vault Dedicated, this should be the public endpoint."

  validation {
    error_message = "The Vault address must be a valid URL"
    condition     = can(regex("https?://.*", var.vault_addr))
  }
}

variable "vpc_link_id" {
  type = string
}


variable "vault_namespace" {
  type    = string
  default = ""

  description = "The Vault namespace to use. If using HCP Vault Dedicated, this should begin with admin/"

  validation {
    error_message = "If set, the namespace must end with a trailing slash"
    condition     = var.vault_namespace == "" || can(regex(".*\\/$", var.vault_namespace))
  }
}

// From these two, we can derive the URL to the Vault server's plugin WIF endpoint
locals {
  proxy_url = "${var.vault_addr}/v1/${var.vault_namespace}identity/oidc/plugins"
}

variable "hosted_zone" {
  type        = string
  description = "The Route 53 hosted zone to use for the demo proxy. If not specified, TF will attempt to derive it from your sandbox"

  default = ""

  validation {
    error_message = "If set, the hosted zone must have a suffix of ${var.hosted_zone_suffix}"
    condition     = var.hosted_zone == "" || can(regex(".*${var.hosted_zone_suffix}$", var.hosted_zone))
  }
}

variable "hosted_zone_suffix" {
  type    = string
  default = ".sbx.hashidemos.io"

  description = "The suffix of the Route 53 hosted zone to use. This is based on the IAM policy restrictions in your AWS account. Do not change this unless you know what you're doing; it probably will not work"
}


variable "proxy_prefix" {
  type        = string
  description = "Prefix to be pre-appended to the proxy URL. Can be empty."

  default = "vault-plugin-wif."
}

locals {
  // define this as a local, so anything which uses it implicitly depends on
  // the Route 53 record being created
  proxy_url_domain = aws_route53_record.domain.fqdn

  proxy_url_prefix = "https://${local.proxy_url_domain}/v1/${var.vault_namespace}identity/oidc/plugins"

  oidc_audience = "${local.proxy_url_domain}:443/v1/${var.vault_namespace}identity/oidc/plugins"
}

variable "aws_mount_path" {
  default = "aws/wif"
}