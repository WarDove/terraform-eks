locals {
  gitlab_ingress = [
    {
      from        = 22
      to          = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
    },
    {
      from        = 80
      to          = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from        = 443
      to          = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}