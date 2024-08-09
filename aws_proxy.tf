
locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Based on https://github.com/hashi-strawb/tf-vault-aws-plugin-wif

#
# API Gateway
#

resource "aws_api_gateway_rest_api" "example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "Plugin WIF Proxy"
      version = "1.0"
    }
    paths = {
      "v1/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            connectionType       = "VPC_LINK"
            connectionId         = var.vpc_link_id
            uri                  = "${local.proxy_url}/.well-known/openid-configuration"
            tlsConfig = {
              insecureSkipVerification = true
              serverNameToVerify       = "vault.jrx.de"
            }
          }
        }
      }
      "v1/${var.vault_namespace}identity/oidc/plugins/.well-known/keys" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            connectionType       = "VPC_LINK"
            connectionId         = var.vpc_link_id
            uri                  = "${local.proxy_url}/.well-known/keys"
            tlsConfig = {
              insecureSkipVerification = true
              serverNameToVerify       = "vault.jrx.de"
            }
          }
        }
      }
    }
  })

  name = "Vault Plugin WIF Proxy for ${var.vault_addr}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.example.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "v1"
}


#
# ACM Cert
#

locals {
  // email_username is everything before @ in local.my_email
  email_username = split("@", local.my_email)[0]

  // derived zone is email_username
  // with dots replaced by dashes
  // and the suffix defined in var.hosted_zone_suffix
  derived_hosted_zone = "${replace(local.email_username, ".", "-")}${var.hosted_zone_suffix}"


  // use var.hosted_zone if set, otherwise use the derived zone
  hosted_zone = var.hosted_zone != "" ? var.hosted_zone : local.derived_hosted_zone
}


data "aws_route53_zone" "demo_zone" {
  name         = local.hosted_zone
  private_zone = false
}

resource "aws_acm_certificate" "example" {
  domain_name       = "${var.proxy_prefix}${local.hosted_zone}"
  validation_method = "DNS"
}

resource "aws_route53_record" "example" {
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.demo_zone.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
}

#
# Custom Domain for Proxy
#

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.demo_zone.zone_id
  name    = "${var.proxy_prefix}${local.hosted_zone}"
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.example.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.example.regional_zone_id
    evaluate_target_health = true
  }
}

resource "aws_api_gateway_domain_name" "example" {
  depends_on = [
    // need to wait for the validation to finish before we can use the domain
    aws_acm_certificate_validation.example
  ]

  domain_name              = aws_acm_certificate.example.domain_name
  regional_certificate_arn = aws_acm_certificate.example.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "example" {
  api_id      = aws_api_gateway_rest_api.example.id
  domain_name = aws_api_gateway_domain_name.example.domain_name
  stage_name  = aws_api_gateway_stage.example.stage_name
}

