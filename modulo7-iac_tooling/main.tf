terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --------- REDE ---------
data "aws_vpc" "main" {
  id = "vpc-06786ee7f7a163059"
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = ["vpc-06786ee7f7a163059"]
  }
}

data "aws_subnet" "internal" {
  id = tolist(data.aws_subnets.all.ids)[0]
}

resource "aws_eip" "main" {
  domain = "vpc"
  tags = { Name = "jewelry-pip" }
}

data "aws_security_group" "main" {
  name   = "jewelry-nsg"
  vpc_id = "vpc-06786ee7f7a163059"
}

resource "aws_network_interface" "main" {
  subnet_id = data.aws_subnet.internal.id
  tags = { Name = "jewelry-nic" }
}

resource "aws_network_interface_sg_attachment" "main" {
  security_group_id    = data.aws_security_group.main.id
  network_interface_id = aws_network_interface.main.id
}

resource "aws_eip_association" "main" {
  allocation_id        = aws_eip.main.id
  network_interface_id = aws_network_interface.main.id
}

# --------- AMI + CHAVE ---------
data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "null_resource" "generate_ssh_key" {
  provisioner "local-exec" {
    command = <<EOT
      if [ ! -f ~/.ssh/id_rsa.pub ]; then
        mkdir -p ~/.ssh
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
      fi
    EOT
  }
}

resource "tls_private_key" "adminuser" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "adminuser" {
  key_name   = "adminuser"
  public_key = tls_private_key.adminuser.public_key_openssh
}

resource "local_file" "adminuser_privkey" {
  content         = tls_private_key.adminuser.private_key_pem
  filename        = pathexpand("~/.ssh/adminuser.pem")
  file_permission = "0600"
}

# --------- EC2 ---------
resource "aws_instance" "jewelry_vm" {
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.adminuser.key_name

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker adminuser

    docker container stop jewelry-app 2> /dev/null

    cd /home/adminuser
    rm -rf proway-docker/
    git clone https://github.com/gui-awk/proway-docker.git
    cd proway-docker/modulo7-iac_tooling

    docker build -t jewelry-app .
    docker run -d -p 8080:80 jewelry-app
  EOF

  tags = { Name = "jewelry-vm" }
}

# --------- OUTPUTS ---------
output "vm_public_ip" {
  value = aws_eip.main.public_ip
}

output "app_url" {
  value = "http://${aws_eip.main.public_ip}:8080"
}
