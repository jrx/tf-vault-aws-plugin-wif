resource "vault_generic_endpoint" "identity_config" {
  path = "identity/oidc/config"
  data_json = jsonencode({
    "issuer" = "https://${local.proxy_url_domain}"
  })

  // delete on this path is unsupported
  disable_delete = true
}

data "aws_iam_policy" "demo_user_permissions_boundary" {
  name = "DemoUser"
}

resource "vault_aws_secret_backend" "aws" {
  path                    = var.aws_mount_path
  identity_token_audience = local.oidc_audience
  role_arn                = aws_iam_role.plugins_role.arn


  # Hashi-specific requirement
  username_template = "{{ if (eq .Type \"STS\") }}{{ printf \"demo-${local.my_email}-%s-%s\" (random 20) (unix_time) | truncate 32 }}{{ else }}{{ printf \"demo-${local.my_email}-vault-%s-%s\" (unix_time) (random 20) | truncate 60 }}{{ end }}"
}

resource "vault_generic_endpoint" "aws-lease" {
  path = "${vault_aws_secret_backend.aws.path}/config/lease"

  data_json = <<EOT
{
  "lease": "5m0s",
  "lease_max": "2h0m0s"
}
EOT

  // delete on this path is unsupported
  disable_delete = true
}

resource "vault_aws_secret_backend_role" "test" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "test"
  credential_type = "iam_user"

  permissions_boundary_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn


  policy_document = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOT
}