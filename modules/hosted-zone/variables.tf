variable "tls_termination" {}
variable "dns_zone" {}
variable "created_manually" {}

variable "vpc_id" {
  description = "Entered VPC id which will make the hosted zone private"
  default     = "none"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id)) || var.vpc_id == "none"
    error_message = "Invalid input:  Possible values are \"none\" or a valid VPC id"
  }
}