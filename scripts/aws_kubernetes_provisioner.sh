#!/bin/bash

# Grant kubectl cli access and patch the coredns deployment to make it compatible with Fargate by removing specific annotation meant for EC2/Managed worker groups
# data "utils_aws_eks_update_kubeconfig" "bootstrap-kubeconfig" already updates the kubeconfig and places it into ~/.kube/config location, similar output would come from:
# aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name ${cluster_name}

set -euo pipefail

check if ec2 is set for compute type in annotations of coredns
EC2_COMPUTE_TYPE="$(kubectl get deploy coredns -n kube-system -o json | jq -r '.spec.template.metadata.annotations["eks.amazonaws.com/compute-type"]')"

if [[ "$EC2_COMPUTE_TYPE" != "null" ]]; then
  kubectl patch deployment coredns -n kube-system --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]';
  kubectl rollout restart -n kube-system deployment coredns
else
  echo "'ec2 compute type' annotation has been removed"
fi

# AWS Load Balancer Controller Service Account
create_sa_alc () {
cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole
EOT
}

# Deploy AWS Load Balancer Controller with Helm chart
helm_install_alc () {
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set region=${REGION} \
    --set vpcId=${VPC_ID} \
    --set clusterName=${CLUSTER_NAME} \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller   
}

# Safe install all resources
helm list -A | grep -q aws-load-balancer || helm_install_alc
kubectl get sa aws-load-balancer-controller -n kube-system > /dev/null 2>&1 || create_sa_alc


# Provisioner resource user to work with this script
# Was provisioned on root module to start this script
# resource "null_resource" "init-kubectl" {
#   depends_on = [
#     module.eks-cluster.kubeconfig
#   ]
#   triggers = {
#     api_endpoint_up = module.eks-cluster.kube_api_endpoint
#   }
#   provisioner "local-exec" {
#     working_dir = "${path.cwd}/scripts"
#     command     = "./aws_kubernetes_provisioner.sh"
#     # Use interpreter "bash" on windows if you have installed git-bash.
#     # On linux no entrypoint needed or you may enter "/bin/bash" 
#     interpreter = ["bash"]
#     environment = {
#       REGION       = local.region
#       ACCOUNT_ID   = local.account_id
#       CLUSTER_NAME = var.cluster_name
#       VPC_ID       = module.eks-cluster.cluster-vpc.id
#     }
#   }
# }


# # log group for eks is created automatically if enabled_cluster_log_types is set on eks_cluster resource so saving here as snippet
# resource "aws_cloudwatch_log_group" "eks-cluster" {
#   name              = "/aws/eks/${var.cluster_name}/cluster"
#   retention_in_days = 7
# }
