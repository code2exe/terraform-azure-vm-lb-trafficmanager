variable "location" {
  description = "Azure Location"
}
variable "prefix" {
  description = "Azure Name Convention"
}

variable "tag_name" {
  type        = string
  description = "Environment Tag Name"
  default = "demo"
}

variable "username" {
  description = "Azure VM Username"
}

variable "user_object_id" {
  description = "User's Object ID from Azure Portal"
}