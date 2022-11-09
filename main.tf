##########################################################################################################
/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>       This module creates hosted-zones      <<<<<<<<<<<<<<<<<<<<<<<<<<<<
  dns_zone        - should be as an apex domain
  tls_termination - set true to create an ACM certificate with wildcard included in sans
  vpc_id          - Possible values are "none" or a valid VPC id, hosted zone will be private if VPC id
   entered
*/
module "huseynov-net" {
  source           = "./modules/hosted-zone"
  dns_zone         = "huseynov.net"
  tls_termination  = true
  created_manually = true
  vpc_id           = "none"

  providers = {
    aws = aws
  }
}
##########################################################################################################
/* >>>>>>>>>>>>>>>>>>>>>       This module provisions a gitlab instance in AWS      <<<<<<<<<<<<<<<<<<<<<<
  external_ssh            - list of cidr block with ssh access to instance, only non-vpc cidr blocks have
   to be added
  subnet_type             - possible values are "private" or "public"
  hosted_zone_id          - possible values are "none" or any valid hosted zone id, requires subdomain
   input
  internal_hosted_zone_id - possible values are "none" or a valid private hosted zone id, internal alb
   alias
   records must be added only to a private hosted zone
  certificate_arn         - possible values are "none" or a valid certificate arn, enables https listener
   requires
   tls_termination
  subdomain               - possible values are "none" or a valid subdomain, requires hosted_zone_id input
  registry_subdomain      - possible values are "none" or a valid subdomain, requires hosted_zone_id input
  user_data               - has to be configured respectively depending on previously mentioned variables
*/
module "gitlab-instance" {
  count = 0
  source                  = "./modules/gitlab-instance"
  name                    = "gitlab"
  ami_owners              = ["099720109477"]
  ami_regex               = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20220610"
  instance_type           = "t2.medium"
  volume_size             = 10
  encrypted_volume        = false
  public_key              = file("${path.cwd}/files/id_rsa.pub")
  external_ssh            = ["185.96.126.106/32", "94.20.66.206/32"]
  vpc                     = module.eks-cluster.cluster-vpc
  subnet_ids              = local.cluster_subnet_ids
  subnet_type             = "public"
  alb                     = true
  internal_alb            = false
  hosted_zone_id          = module.huseynov-net.zone_id
  internal_hosted_zone_id = "none"
  certificate_arn         = module.huseynov-net.certificate_arn
  tls_termination         = true
  subdomain               = "gitlab"
  registry_subdomain      = "docker"

  user_data = templatefile("${path.cwd}/templates/gitlab_user_data.tpl",
    {
      node_name                = "Gitlab-Instance-Test"
      gitlab_url               = "https://gitlab.huseynov.net"
      repository_url           = "https://docker.huseynov.net"
      X-Forwarded-Proto-Header = "https"
  })

  providers = {
    aws = aws
  }
}
##########################################################################################################
/* >>>>>>>>>>>>>>>>>>>>>>>>>>       This module provisions an EKS cluster      <<<<<<<<<<<<<<<<<<<<<<<<<<<
  load_balancer - creates aws load balancer controller resources including service account and all iam
   policies for the service account
  fargate_only_cluster - creates fargate profile for kube-system namespace to enable coredsn and other
   system resources created after cluster provisioning
  managed_node_groups -
  external_ssh -
*/
module "eks-cluster" {
  source               = "./modules/eks-cluster"
  cluster_name         = "gitlab-cluster"
  public_api           = true
  load_balancer        = true
  #fargate_profiles     = local.fargate_profiles
  managed_node_groups  = local.managed_node_groups
  public_key           = file("${path.cwd}/files/id_rsa.pub")
  external_ssh         = ["185.96.126.106/32", "94.20.66.206/32"]
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
##########################################################################################################
/* >>>>>>>>>>>>>>>>>>>>       This module provisions gitlab-runners on EKS      <<<<<<<<<<<<<<<<<<<<<<<<<<
*/
module "gitlab-runners" {
  count  = var.runner_registration_token != "" ? 1 : 0
  source = "./modules/gitlab-runners"
  depends_on = [
    module.eks-cluster,
    module.gitlab-instance
  ]

  runner_registration_token = var.runner_registration_token
  gitlab_url                = "https://gitlab.huseynov.net/"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
}
##########################################################################################################
# TODO: Node affinity rules for spinning system resources on on-demand groups
# TODO: Add ec2 node groups with some logic to eks module
# TODO: Implement Vertical and Horizontal auto scaling with eks module
# https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html#cluster-autoscaler
# https://www.eksworkshop.com/beginner/080_scaling/
# https://aws.github.io/aws-eks-best-practices/cluster-autoscaling/
# TODO: ECR pull images from pod - OIDC provider role for service account
# TODO: AWS backups integrate with gitlab instance and make modular for all






