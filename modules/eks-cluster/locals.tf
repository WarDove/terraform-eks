locals {
  fargate_only_cluster = var.managed_node_groups == {} && var.fargate_profiles != {}
}