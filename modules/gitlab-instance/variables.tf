variable "instance_type" {}
variable "vpc" {}
variable "gitlab-version" {}
variable "volume_size" {}
variable "subnet_ids" {}
variable "subnet_type" {}
variable "ssh_cidr_blocks" {}

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
