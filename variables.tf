variable "aws_region" {
  type        = string
  description = "The AWS region for the secure data enclave"
  default     = "ap-southeast-2" # Sydney
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the AI and Vector DB"
  default     = "australia-southeast1" # Sydney
}

variable "gcp_project_id" {
  type        = string
  description = "Your Google Cloud Project ID"
}

variable "azure_subscription_id" {
  type        = string
  description = "Your Azure Subscription ID for Entra ID"
}
variable "pinecone_api_key" {
  description = "API Key for Pinecone Vector DB"
  type        = string
  sensitive   = true
}