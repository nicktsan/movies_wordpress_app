terraform {
  backend "s3" {
    bucket               = "movies-terraform-backend"
    key                  = "terraform.tfstate"
    region               = var.region
    workspace_key_prefix = "wordpress"
    dynamodb_table       = "movies-db-backend"
    encrypt              = true
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
