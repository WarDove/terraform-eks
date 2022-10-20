locals {
  gitlab_ingress = [
    {
      from        = 0
      to          = 0
      protocol    = -1
      cidr_blocks = [var.vpc.cidr_block]
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
    },
    {
      from        = 5050
      to          = 5050
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  
  subnet_ids   = var.subnet_ids[var.subnet_type]
  internal_alb = var.alb == "internal"
  create_alb   = var.alb != "none"
  allocate_eip = var.subnet_type == "public" && var.alb == "none"
  # checks if tls_termination value corresponds to certificate arn
  tls_input_verify = var.tls_termination == (var.certificate_arn != "none")
}
