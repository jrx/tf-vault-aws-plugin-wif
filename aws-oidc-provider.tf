
resource "time_sleep" "wait" {
  create_duration = "60s"

  depends_on = [aws_route53_record.domain]
}

data "tls_certificate" "vault_certificate" {
  url = local.proxy_url_prefix

  depends_on = [time_sleep.wait]
}


resource "aws_iam_openid_connect_provider" "vault_provider" {
  url = data.tls_certificate.vault_certificate.url

  client_id_list  = [local.oidc_audience]
  thumbprint_list = [data.tls_certificate.vault_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "plugins_role" {
  name = "vault-oidc-plugins"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${aws_iam_openid_connect_provider.vault_provider.arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity"
   }
 ]
}
EOF


  inline_policy {
    name = "CreateChildUser"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "iam:CreateUser",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
          Condition = {
            "StringEquals" : {
              "iam:PermissionsBoundary" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DemoUser"
            }
          }
        },
      ]
    })
  }

  inline_policy {
    name = "ManageAndDeleteChildren"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "iam:DeleteUser",
            "iam:DeleteUserPolicy",
            "iam:PutUserPolicy",
            "iam:TagUser",
            "iam:UntagUser",
            "iam:CreateAccessKey",
            "iam:DeleteAccessKey",
            "iam:List*",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
        },
      ]
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}