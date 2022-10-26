#!/bin/bash

helm repo add gitlab https://charts.gitlab.io

helm install --namespace gitlab gitlab-runner -f values.yaml gitlab/gitlab-runner \
   --set gitlabUrl=http://gitlab.huseynov.net,runnerRegistrationToken=$1

# helm upgrade --namespace gitlab -f values.yaml gitlab-runner gitlab/gitlab-runner
