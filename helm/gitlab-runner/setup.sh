#!/bin/bash

helm repo add gitlab https://charts.gitlab.io

#helm install --namespace gitlab --name gitlab-runner -f values.yml gitlab/gitlab-runner

helm install --namespace gitlab --name gitlab-runner -f values.yml \
   --set gitlabUrl=http://gitlab.huseynov.net,runnerRegistrationToken=$1 \
   gitlab/gitlab-runner