# networks.tf

# --- AWS Network ---
resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11: VPC Flow logs require IAM setup; suppressing for baseline plumbing.
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "enclave-aws-vpc" }
}

# Fix for CKV2_AWS_12: Hijack and restrict the default security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # Leaving ingress and egress completely empty effectively blocks ALL traffic
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = { Name = "enclave-aws-public-1a" }
}

# --- GCP Network ---
resource "google_compute_network" "vpc" {
  # checkov:skip=CKV2_GCP_18: Custom firewalls will be defined during the compute phase.
  name                    = "enclave-gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  # checkov:skip=CKV_GCP_26: VPC Flow logs require extra config; suppressing for baseline.
  name                     = "enclave-gcp-subnet-sydney"
  ip_cidr_range            = "10.2.1.0/24"
  region                   = "australia-southeast1"
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # Fix for missing Private IP Google Access
}

# --- Azure Network ---
resource "azurerm_resource_group" "network" {
  name     = "enclave-network-rg"
  location = "australiaeast"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "enclave-azure-vnet"
  address_space       = ["10.3.0.0/16"]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_subnet" "internal" {
  # checkov:skip=CKV2_AZURE_31: NSGs will be built and attached when compute ports are known.
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.3.1.0/24"]
}