#!/bin/bash

# Pre-requisite: kubectl and jq needs to be instellad
# Grant kubectl cli access and patch the coredns deployment to make it compatible with Fargate by removing specific annotation meant for EC2/Managed worker groups
# data "utils_aws_eks_update_kubeconfig" "bootstrap-kubeconfig" already updates the kubeconfig and places it into ~/.kube/config location, similar output would come from:
# aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name ${cluster_name}

set -euo pipefail

# check if ec2 is set for compute type in annotations of coredns
EC2_COMPUTE_TYPE="$(kubectl get deploy coredns -n kube-system -o json | jq -r '.spec.template.metadata.annotations["eks.amazonaws.com/compute-type"]')"

if [[ ${FARGATE_ONLY} == true && ${EC2_COMPUTE_TYPE} != null ]]; then
  kubectl patch deployment coredns -n kube-system --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]';
  kubectl rollout restart -n kube-system deployment coredns
elif [[ ${FARGATE_ONLY} == false && ${EC2_COMPUTE_TYPE} != ec2 ]]; then
  kubectl patch deploy coredns -n kube-system -p '{"spec": {"template": {"metadata": {"annotations": {"eks.amazonaws.com/compute-type": "ec2"}}}}}'  
fi