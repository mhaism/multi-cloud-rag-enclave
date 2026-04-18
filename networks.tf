# networks.tf

# --- AWS Network ---
resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "enclave-aws-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = { Name = "enclave-aws-public-1a" }
}

# --- GCP Network ---
resource "google_compute_network" "vpc" {
  name                    = "enclave-gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "enclave-gcp-subnet-sydney"
  ip_cidr_range = "10.2.1.0/24"
  region        = "australia-southeast1"
  network       = google_compute_network.vpc.id
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
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.3.1.0/24"]
}