DevSecOps

##  Configuração da VPC 

### Criando a VPC

- No console AWS, busque por VPC.
- Dentro das configurações, selecione as seguinte opções:
    - **Name tag auto-generation:** nome desejado
    - **IPv4 CIDR block:** 10.0.0.0/16
    - **Number of Availability Zones (AZs):** 2
    - **Number of public subnets:** 2
    - **Number of private subnets:** 2
    - **NAT gateways:** 1 per AZ - Escolhendo essa opção, as rotas serão configuradas automaticamente.

##  Configuração dos Security Groups

### SG do Load Balancer

- **Inbound Rules :**
    - Type: HTTP
    - Porta Range: 80
    - Source Type: Anywhere-IPv4
    - Source:  0.0.0.0/0
    
    - **Type: HTTPS**
    - Porta Range: 443
    - Source Type: Anywhere-IPv4
    - Source:  0.0.0.0/0

### SG das Instâncias EC2

- **Inbound Rules :**
    - Type: HTTP
    - Porta Range: 80
    - Source Type: Custom
    - Source:  SG Load Balancer
    
    - Type: HTTPS
    - Porta Range: 443
    - Source Type: Custom
    - Source:  SG Load Balancer
    

### SG do Banco de Dados

- **Inbound Rules :**
    - Type: MySQL/Aurora
    - Porta Range: 3306
    - Source Type: Custom
    - Source:  SG Instâncias

### SG do Load Balancer

- **Inbound Rules :**
    - Type: HTTP
    - Porta Range: 80
    - Source Type: Anywhere-IPv4
    - Source:  0.0.0.0/0
    
    - **Type: HTTPS**
    - Porta Range: 443
    - Source Type: Anywhere-IPv4
    - Source:  0.0.0.0/0

###  SG do Elastic File System

- **Inbound Rules :**
    - Type: NFS
    - Porta Range: 2049
    - Source Type: Custom
    - Source:  Security Group das Instâncias

## Configuração do Elastic File System (EFS)

### Criação do sistema de arquivos

- EM EFS e clique em CREATE FILE SYSTEM
- CUSTOMIZE
- File system type: Regional
- Desmarque a opção *Enable automatic backups*.
- Clique em NEXT
- Em Network  selecione a VPC criada para o projeto
- Na de Mount Targets  selecione a Availability Zone, security group do EFS e a subnet privada de cada zona.
- CREATE

## Configuração RDS

### Criando o Banco de Dados

- Em RDS, clique em DATABASES, CREATE DATABASE
- Selecione:
    - Standart create
    - Engine options: MySQL
    - Template: Free Tier
- configurações:
    - DB instance identifier: escolhe o nome de acordo com o projeto
    - Master username: defina um nome de usuário
    - Master password: defina uma senha
    - DB instance class:  db.t3.micro
    - Existing VPC security groups: selecione a VPC do Banco de Dados
    - Em **Additional Configuration** defina um nome para o Banco de Dados, caso contrário ele não será realmente criado
    - Desmarque a opção **Enable automated backups**
    - Por fim, clique em `CREATE DATABASE`

## Elastic Load Balancer

### - Criando o Load Balancer

- EC2, clique em`LOAD BALANCERS
- Clique em CREATE LOAD BALANCER e escolha o tipo Classic Load Balancer
- Defina um nome
- Scheme Internet-facing
- VPC criada para o projeto
- Marque as duas AZs e suas subnets públicas
- Selecione o Security Group do Load Balancer
- Clique em `CREATE LOAD BALANCER`

## Configuração do Auto Scaling Group

- Na seção de EC2, busque por Auto Scaling Group
- CREATE AUTO SCALING GROUP

### Criando um template de instância

- Clique em Create a launch template 
- Defina um nome para o seu template
- Em Application and OS Images, escolheremos o Amazon Linux 2
- Instance type: t2.micro (gratuita)
- Escolha uma Key pair ou gere uma nova
- Escolha o Security Group da instâncias

```bash
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
```

### Criando o Auto Scaling Group

- Volte para a página do Auto Scaling Group e selecione a instância criada
- Clique em NEXT
- Selecione a VPC do projeto
- Selecione as duas subnets privadas
- Clique em NEXT
- Loand Balancing: Attach to an existing load balancer
- Choose from Classic Load Balancers
- Selecione o Load Balancer criado anteriormente
- Clique em NEXT
- Desired capacity: 2
- Min desired capacity: 1
- Max desired capacity: 2
- Clique em NEXT até chegar em CREATE AUTO SCALING GROUP
