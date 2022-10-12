#!/bin/bash

# Pre-requisites: Helm  v3.8.2 (3.9 is broken atm)
# https://github.com/helm/helm/releases/tag/v3.8.2

#   The deployed chart doesn't receive security updates 
#   automatically. You need to manually upgrade to a newer
#   chart when it becomes available. When upgrading, change 
#   install to upgrade in the previous command, but run the 
#   following command to install the TargetGroupBinding custom
#   resource definitions before running the previous command.
#    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

set -euo pipefail

region=eu-central-1
cluster_name=eks-cluster
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
vpc_id=$(aws ec2 describe-vpcs --region ${region} | jq -r '.Vpcs[1].VpcId')


helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set region=${region} \
  --set vpcId=${vpc_id} \
  --set clusterName=${cluster_name} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set deploymentAnnotations."alb\.ingress\.kubernetes\.io/target-type"="ip" 
  kubectl get deployment -n kube-system aws-load-balancer-controller
