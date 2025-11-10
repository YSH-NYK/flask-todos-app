#!/bin/bash

# Install dependencies
sudo yum update -y
sudo yum install -y python3 python3-pip nginx

# Create venv
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

# Copy env
cp /home/ec2-user/todos-deploy/.env /home/ec2-user/app/.env

# Restart systemd Gunicorn
sudo systemctl daemon-reload
sudo systemctl restart gunicorn

# Restart nginx
sudo systemctl restart nginx

echo "Deployment Complete on Amazon Linux"
