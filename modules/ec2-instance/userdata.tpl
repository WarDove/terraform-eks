#!/bin/bash
sudo hostnamectl set-hostname ${nodename}~$(curl http://169.254.169.254/latest/meta-data/instance-id)