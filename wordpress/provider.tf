provider "aws" {
  region = var.region
}

provider "cloudflare" {
  api_token = data.aws_ssm_parameter.cloudflare_token.value
}
