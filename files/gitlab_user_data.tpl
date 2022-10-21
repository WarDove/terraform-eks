#!/bin/bash
sudo hostnamectl set-hostname "${node_name}~$(curl http://169.254.169.254/latest/meta-data/instance-id)"
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl
sudo apt-get install -y postfix
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo EXTERNAL_URL="https://${gitlab_url}" apt-get install gitlab-ee





