#!/bin/bash
sudo hostnamectl set-hostname "${node_name}-~$(curl http://169.254.169.254/latest/meta-data/instance-id)"
# GITLAB-EE
#sudo apt-get update
#sudo apt-get install --assume-yes curl openssh-server ca-certificates tzdata perl
#sudo debconf-set-selections <<< "postfix postfix/mailname string <soma_mail_url>"
#sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
#apt-get install --assume-yes postfix
#curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
#sudo EXTERNAL_URL="https://${gitlab_url}" apt-get install --assume-yes gitlab-ee=15.4.3-ee.0

# GITLAB-CE
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl openssh-server tzdata
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
sudo EXTERNAL_URL="http://${gitlab_url}" apt-get install --assume-yes gitlab-ce=15.4.3-ce.0




