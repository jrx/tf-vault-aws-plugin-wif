output "proxy_url" {
  depends_on = [aws_api_gateway_base_path_mapping.example]

  description = "API Gateway Domain URL (self-signed certificate)"
  value       = "${local.proxy_url_prefix}/.well-known/openid-configuration"
}

output "test_command" {
  value = "vault read ${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name}"
}