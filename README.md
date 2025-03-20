## DevSecOps

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

    - Type: SSH
    - Porta Range: 22
    - Source Type: Anywhere-IPv4
    - Source:  0.0.0.0/0
    

### SG do Banco de Dados

- **Inbound Rules :**
    - Type: MySQL/Aurora
    - Porta Range: 3306
    - Source Type: Custom
    - Source:  SG Instâncias

###  SG do Elastic File System

- **Inbound Rules :**
    - Type: NFS
    - Porta Range: 2049
    - Source Type: Custom
    - Source:  Security Group das Instâncias

## Criação e acesso ao Bastion Host
### Para acessarmos as instâncias privadas via SSH, podemos configurar um Bastion Host em uma sub-rede pública.

 - Crie uma instância EC2, com uma nova chave .pem e sem um script user_data.
 - Acesse o CMD do Windows e navegue até a pasta onde estão armazenadas as chaves .pem.
 - Digite o comando "type" e o nome de uma das key pairs da EC2 privada que deseja se conectar.
 - Copie o conteúdo da key pair.
 - No painel de instâncias na AWS, selecione sua instância Bastion Host e clique em "Connect".
 - Na categoria "SSH Client" copie o último comando -> "Example";
 - Cole o comando e rode em seu CMD, escreva "yes" e permita a conexão SSH;
 - Após a conexão bem-sucedida, crie um novo arquivo .pem digitando o comando "nano exemplo-nome-chave-ec2-privada-1.pem".
 - Dentro do nano, cole o conteúdo de sua key pair anteriormente copiada, salve-o e saia do nano.
 - Dê permissão para o arquivo digitando o comando "chmod 400 nome-chave-ec2-privada-1.pem".
 - No painel de instâncias na AWS, selecione sua instância privada e clique em "Connect".
 - Na categoria "SSH Client" copie o último comando -> "Example";
 - Cole o comando, mude o nome da chave para "nome-chave-ec2-privada-1.pem".


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
#!/bin/bash

# Atualiza o sistema e instala Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Instala o Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instala e configura o Amazon EFS
sudo yum install -y amazon-efs-utils
sudo systemctl start amazon-efs-utils
sudo systemctl enable amazon-efs-utils

# Cria o diretório para o EFS e monta
sudo mkdir -p /mnt/efs
echo ""*<EFS_DNS>*":/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Cria o diretório do WordPress
sudo mkdir -p /mnt/efs/wordpress
sudo chown -R ec2-user:ec2-user /mnt/efs/wordpress
sudo chmod -R 775 /mnt/efs/wordpress

# Cria o arquivo docker-compose.yaml
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

# Cria o serviço systemd para gerenciar o Docker Compose
sudo tee /etc/systemd/system/docker-compose.service > /dev/null <<EOF
[Unit]
Description=Docker Compose Application
Requires=docker.service
After=docker.service

[Service]
WorkingDirectory=/mnt/efs/
ExecStart=/usr/local/bin/docker-compose -f /mnt/efs/docker-compose.yaml up -d
ExecStop=/usr/local/bin/docker-compose -f /mnt/efs/docker-compose.yaml down
Restart=always
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF 

# Recarrega o systemd e ativa o serviço
sudo systemctl daemon-reload
sudo systemctl enable docker-compose
sudo systemctl start docker-compose

# Aguarda o WordPress iniciar
sleep 30

# Cria a página de Health Check
docker exec $(docker ps -q -f "ancestor=wordpress:latest") bash -c 'echo "<?php http_response_code(200); ?>" > /var/www/html/healthcheck.php'
```

## Criando o Auto Scaling Group

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

## Regras de Auto Scaling

### Criar Política de Escala para Aumentar a Capacidade

- Criar um Alarme no CloudWatch
- Acesse o AWS CloudWatch.
- Vá para Alarms > Create Alarm.
- Escolha a métrica Application Load Balancer > Per-Target Metrics.
- Selecione RequestCountPerTarget e escolha o Target Group correto.
- Configure a condição:
- Threshold Type: Static
- Quando a média for maior que: 200 requisições por minuto
- Duração: 2 períodos de 1 minuto
- Clique em Next.
- Escolha a ação Auto Scaling Action e selecione o ASG.
- Selecione Adicionar 1 instância e finalize o alarme.

#### Passo 2: Criar a Política de Escala no Auto Scaling Group

- Acesse o EC2 > Auto Scaling Groups.
- Escolha o seu Auto Scaling Group.
- Vá para a aba Automatic Scaling.
- Clique em Create Scaling Policy.
- Escolha Step Scaling e associe ao alarme criado.
- Configure a ação:
- Incrementar 1 instância.
- Cooldown: 120 segundos.
- Salve a política.

### Criar Política de Escala para Reduzir a Capacidade

- Criar um Alarme no CloudWatch
- Acesse o AWS CloudWatch.
- Vá para Alarms > Create Alarm.
- Escolha a métrica Application Load Balancer > Per-Target Metrics.
- Selecione RequestCountPerTarget e escolha o Target Group correto.
- Configure a condição:
- Threshold Type: Static
- Quando a média for menor que: 10 requisições por minuto
- Duração: 5 períodos de 1 minuto
- Clique em Next.
- Escolha a ação Auto Scaling Action e selecione o ASG.
- Selecione Remover 1 instância e finalize o alarme.

#### Passo 2: Criar a Política de Escala no Auto Scaling Group

- Acesse o EC2 > Auto Scaling Groups.
- Escolha o seu Auto Scaling Group.
- Vá para a aba Automatic Scaling.
- Clique em Create Scaling Policy.
- Escolha Step Scaling e associe ao alarme criado.
- Configure a ação:
- Remover 1 instância.
- Cooldown: 300 segundos.
- Salve a política.
