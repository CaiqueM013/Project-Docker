#!/usr/bin/env bash

sudo yum update -y
sudo yum upgrade -y
sudo yum install -y amazon-efs-utils

mkdir -p /mnt/efs
sudo mount -t efs -o tls "*<EFS_DNS>*":/ /mnt/efs

sudo yum install docker -y
sudo usermod -a -G docker ec2-user
newgrp docker
sudo systemctl enable docker.service
sudo systemctl start docker.service

sudo curl -L [https://github.com/docker/compose/releases/latest/download/docker-compose-$](https://github.com/docker/compose/releases/latest/download/docker-compose-$)(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

cat << EOF > /home/ec2-user/docker-compose.yml
services:
wordpress:
image: wordpress:latest
ports:
- "80:80"
environment:
WORDPRESS_DB_HOST: "*<RDS_ENDPOINT>*"
WORDPRESS_DB_USER: "*<USER>*"
WORDPRESS_DB_PASSWORD: "*<SENHA>*"
WORDPRESS_DB_NAME: "*<NOME_DB>*"
volumes:
- /mnt/efs/wp-content:/var/www/html/wp-content
restart: always
EOF

cd /home/ec2-user
docker-compose up -d