#!/bin/bash

sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo yum install -y amazon-efs-utils
sudo systemctl start amazon-efs-utils
sudo systemctl enable amazon-efs-utils

sudo mkdir -p /mnt/efs
echo ""*<EFS_DNS>*":/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

sudo mkdir -p /mnt/efs/wordpress
sudo chown -R ec2-user:ec2-user /mnt/efs/wordpress
sudo chmod -R 775 /mnt/efs/wordpress

sudo tee /mnt/efs/docker-compose.yaml > /dev/null <<EOF
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: "*<RDS_ENDPOINT>*"
      WORDPRESS_DB_NAME: "*<NOME_DB>*"
      WORDPRESS_DB_USER: "*<USER>*"
      WORDPRESS_DB_PASSWORD: "*<SENHA>*"
    volumes:
      - /mnt/efs/wordpress:/var/www/html
EOF

docker-compose -f /mnt/efs/docker-compose.yaml up -d

docker exec $(docker ps -q -f "ancestor=wordpress:latest") bash -c 'echo "<?php http_response_code(200); ?>" > /var/www/html/healthcheck.php'
