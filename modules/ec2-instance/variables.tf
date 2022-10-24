variable "instance_type" {}
variable "vpc" {}
variable "name" {}
variable "user_data" {}
variable "public_key" {}
variable "ami_owners" {}
variable "ami_regex" {}
variable "volume_size" {}
variable "external_ssh" {}
variable "subnet_ids" {}
variable "encrypted_volume" {}

variable "hosted_zone_id" {
  default = "none"
}

variable "subdomain" {
  default = "none"
}

variable "registry_subdomain" {
  default = "none"
}

variable "subnet_type" {
  default     = "none"
  type        = string
  description = "Certificate arn to enable tls termination - also can be set to none"

  validation {
    condition     = var.subnet_type == "private" || var.subnet_type == "public"
    error_message = "Invalid input: Possible values are \"private\" or \"public\""
  }
}

variable "tls_termination" {
  default = false
}

variable "certificate_arn" {
  default     = "none"
  type        = string
  description = "Certificate arn to enable tls termination - also can be set to none"

  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn)) || var.certificate_arn == "none"
    error_message = "Invalid input: Possible values are \"none\" or a valid certificate arn"
  }
}

variable "alb" {
  default     = "none"
  type        = string
  description = "Application load balancer type (internal or external) - also can be set to none"

  validation {
    condition     = var.alb == "none" || var.alb == "internal" || var.alb == "external"
    error_message = "Invalid input: Possible values are \"none\", \"internal\" or \"external\""
  }
}
