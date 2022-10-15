#!/bin/bash

# PRE-REQUISITES:  AWS CLI, KUBECTL and GRAPHVIZ (DOT)
# https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-with-curl-on-windows
# This script needs a soft link to variables.tf and terraform.tfvars filesin order to get values from terraform console
set -euo pipefail

varfile="terraform.tfvars"
region="$(echo 'var.region' | terraform console -var-file ${varfile} | tr -d '\"')"
cluster_name="$(echo 'var.cluster_name' | terraform console -var-file ${varfile} | tr -d '\"')"
profile="$(echo 'var.profile' | terraform console -var-file ${varfile} | tr -d '\"')"
vpc_id="$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${cluster_name}-vpc" --query Vpcs[0].VpcId --output text --profile ${profile} --region ${region})"
account_id="$(aws sts get-caller-identity --query Account --output text --profile ${profile})"

# Grant kubectl cli access and patch the coredns deployment to make it compatible with Fargate by removing specific annotation meant for EC2/Managed worker groups
aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name ${cluster_name}
kubectl patch deployment coredns -n kube-system --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]'
kubectl rollout restart -n kube-system deployment coredns

# AWS Load Balancer Controller Service Account
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
    eks.amazonaws.com/role-arn: arn:aws:iam::${account_id}:role/AmazonEKSLoadBalancerControllerRole
EOT

# Deploy AWS Load Balancer Controller with Helm chart
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set region=${region} \
  --set vpcId=${vpc_id} \
  --set clusterName=${cluster_name} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  
  kubectl get deployment -n kube-system aws-load-balancer-controller