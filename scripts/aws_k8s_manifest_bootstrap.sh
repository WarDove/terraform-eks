#!/bin/bash
# pre requisites
# AWS CLI and KUBECTL
#https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-with-curl-on-windows

profile="$(echo 'var.profile' | terraform console | tr -d '\"')"
region="$(echo 'var.region' | terraform console | tr -d '\"')"

aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name eks-cluster    
kubectl patch deployment coredns -n kube-system --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]'
kubectl rollout restart -n kube-system deployment corednsaws_account_id="$(aws sts get-caller-identity --query Account --output text --profile ${profile})"