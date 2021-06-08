variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}
variable "tag_name" {
  type        = string
  description = "Environment Tag Name"
  default     = "demo"
}
variable "tenant_id" {
  description = "Azure Tenant ID"
}
variable "client_id" {
  type = string
  description = "Azure Client ID"
}
variable "client_secret" {
  type = string
  description = "Azure Client Secret"
}
variable "location" {
  description = "Azure East location"
}

variable "north_location" {
  description = "Azure North location"
}
variable "prefix" {
  description = "Azure Name Convention"
}

variable "vm_username" {
  description = "Azure VM Username"
}

variable "user_object_id" {
  description = "User's Object ID from Azure Portal"
}