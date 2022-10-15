#!/bin/bash

# Grant kubectl cli access and patch the coredns deployment to make it compatible with Fargate by removing specific annotation meant for EC2/Managed worker groups
# data "utils_aws_eks_update_kubeconfig" "bootstrap-kubeconfig" already updates the kubeconfig and places it into ~/.kube/config location, similar output would come from:
# aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name ${cluster_name}

set -euo pipefail

# check if ec2 is set for compute type in annotations of coredns
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

# Deploy AWS Load Balancer Controller with Helm chartget
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