
output "test_command" {
  value = "vault read ${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name}"
}
