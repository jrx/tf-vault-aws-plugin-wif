terraform {
  # cloud {
  #   organization = "hashi_strawb_testing"

  #   workspaces {
  #     name = "vault-aws-secrets-wif"
  #   }
  # }
}

provider "vault" {
  namespace = ""
}