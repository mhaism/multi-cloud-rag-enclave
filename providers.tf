# providers.tf

terraform {
  required_version = ">= 1.5.0"

  # 1. THE BACKEND BLOCK MUST LIVE INSIDE THIS 'terraform' BLOCK
  # backend "s3" {
  #  bucket         = "multi-cloud-rag-state-mm-041826" 
  # key            = "global/s3/terraform.tfstate"
  # region         = "ap-southeast-2"
  # dynamodb_table = "multi-cloud-rag-state-locks"
  # encrypt        = true
  # }

  # 2. REQUIRED PROVIDERS ALSO LIVE INSIDE THE 'terraform' BLOCK
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 3. ACTUAL PROVIDER CONFIGS MUST LIVE OUTSIDE THE 'terraform' BLOCK
provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}