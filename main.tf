# Declare your hosted zone and create certificates via ACM
module "huseynov-net" {
  source = "./modules/hosted-zone"
  # This should be set as an apex domain
  dns_zone = "huseynov.net"
  # Set tls_termination to true if you want to create an ACM certificate
  # with wildcard included in sans.
  tls_termination  = true
  created_manually = true
  # Hosted zone will be private if VPC id entered
  # Possible values are "none" or a valid VPC id
  vpc_id = "none"

  providers = {
    aws = aws
  }
}

# Provision a gitlab instance in AWS
module "gitlab-instance" {
  source           = "./modules/gitlab-instance"
  name             = "gitlab"
  ami_owners       = ["099720109477"]
  ami_regex        = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20220610"
  instance_type    = "t2.medium"
  volume_size      = 10
  encrypted_volume = false
  public_key       = file("${path.cwd}/files/id_rsa.pub")

  user_data = templatefile("${path.cwd}/templates/gitlab_user_data.tpl",
    {
      node_name                = "Gitlab-Instance-Test"
      gitlab_url               = "https://gitlab.huseynov.net"
      repository_url           = "https://docker.huseynov.net"
      X-Forwarded-Proto-Header = "https"
  })

  # list of cidr block with ssh access to instance
  # Note that only non-vpc cidr blocks have to be added
  external_ssh = ["185.96.126.106/32", "94.20.66.187/32"]
  vpc          = module.eks-cluster.cluster-vpc
  subnet_ids   = local.cluster_subnet_ids
  # Possible values are "private" or "public"
  subnet_type  = "public"
  alb          = true
  # Possible values are "none" or a valid hosted zone id
  # If not set to "none" subdomain must be set as well
  hosted_zone_id = module.huseynov-net.zone_id
  # Internal alb alias records must be added only to a private hosted zone
  internal_alb = false
  # Possible values are "none" or a valid private hosted zone id
  internal_hosted_zone_id = "none"
  # Enter certificate arn to enable https listener and http -> https redirect
  # Possible values are "none" or a valid certificate arn
  # If not set to "none" tls_termination must be turned on
  # If alb is set to "none" then certificate_arn must be set to "none" or omitted.
  certificate_arn = module.huseynov-net.certificate_arn
  tls_termination = true
  # Possible values are "none" or a valid subdomain
  # If not set to "none" hosted_zone_id must be set as well
  subdomain = "gitlab"
  # Possible values are "none" or a valid subdomain
  # If not set to "none" hosted_zone_id must be set as well
  registry_subdomain = "docker"
  # Must be noted that if alb is set to "none" and subnet_type
  # is set to "private" setting both subdomain and hosted_zone_id
  # Will trigger an error, but if subnet_type is set to be public
  # dns record will be created for elastic ip of the instance
  # without tls_termination
  providers = {
    aws = aws
  }
}

# Provision an EKS cluster
module "eks-cluster" {
  source               = "./modules/eks-cluster"
  cluster_name         = "gitlab-cluster"
  public_api           = true
  load_balancer        = true
  fargate_only_cluster = true
  fargate_profiles     = local.fargate_profiles
  vpc_cidr             = "10.0.0.0/16"
  az_count             = 2
  az_names             = local.az_names
  region               = local.region
  account_id           = local.account_id
  profile              = var.profile

  providers = {
    aws        = aws
    utils      = utils
    helm       = helm
    kubernetes = kubernetes
  }
}

# TODO: Implement Vertical and Horizontal auto scaling with eks module
# TODO: Add ec2 node groups with some logic to eks module
# TODO: AWS backups integrate with gitlab instance and make modular for all


