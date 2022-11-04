variable "vpc_cidr" {}
variable "az_names" {}
variable "az_count" {}
variable "cluster_name" {}
variable "region" {}
variable "profile" {}
variable "account_id" {}
variable "public_api" {}
variable "load_balancer" {}
variable "fargate_only_cluster" {}
variable "managed_node_groups" {
  default = {}
}
variable "fargate_profiles" {
  default = {}
}