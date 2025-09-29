#!/bin/bash

# EC2 user data script to install Ansible on Amazon Linux 2023

# Log message
echo "[$(date)] Installing boto3..."

# Install boto3
dnf install python3-boto3 -y

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Installing ansible-core..."

# Install Ansible core
dnf install ansible-core -y

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Installing ansible..."

# Install Ansible
dnf install ansible -y

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Installing Ansible amazon.aws collection..."

# Install Ansible amazon.aws collection
ansible-galaxy collection install amazon.aws

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Installing Ansible community.general collection..."

# Install Ansible community.general collection
ansible-galaxy collection install community.general

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Creating /opt/ansible directory..."

# Create the /opt/ansible directory
mkdir /opt/ansible

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Downloading files from S3 bucket..."

# Download the contents of the S3 bucket
aws s3 sync s3://${aws_s3_bucket} /opt/ansible/

# Log message
echo "[$(date)] OK"

# Log message
echo "[$(date)] Executing Ansible playbook..."

# Apply the Ansible playbook
ansible-playbook /opt/ansible/main.yml

# Log message
echo "[$(date)] OK"
