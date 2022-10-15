data "aws_caller_identity" "current" {}
data "aws_availability_zones" "current" {
  state = "available"
}

locals {
  az_names   = data.aws_availability_zones.current.names
  region     = data.aws_availability_zones.current.id
  account_id = data.aws_caller_identity.current.account_id
}