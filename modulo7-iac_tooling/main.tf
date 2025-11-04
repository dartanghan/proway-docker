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

resource "azurerm_resource_group" "main" {
  name     = "jewelry-app-rg"
  location = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "jewelry-vpc"
  }
}

resource "aws_subnet" "internal" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "internal"
  }
}


resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name = "jewelry-pip"
  }
}


resource "aws_security_group" "main" {
  name   = "jewelry-nsg"
  vpc_id = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP 8080"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "jewelry-nsg"
  }
}



resource "aws_network_interface" "main" {
  subnet_id = aws_subnet.internal.id

  tags = {
    Name = "jewelry-nic"
  }
}

resource "aws_eip_association" "main" {
  allocation_id        = aws_eip.main.id
  network_interface_id = aws_network_interface.main.id
}


resource "aws_network_interface_sg_attachment" "main" {
  security_group_id    = aws_security_group.main.id
  network_interface_id = aws_network_interface.main.id
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "adminuser" {
  key_name   = "adminuser"
  public_key = file("~/.ssh/id_rsa.pub")
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "adminuser" {
  key_name   = "adminuser"
  public_key = file("~/.ssh/id_rsa.pub")
}

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

  tags = {
    Name = "jewelry-vm"
  }
}

output "vm_public_ip" {
  value = aws_eip.main.public_ip
}

output "app_url" {
  value = "http://${aws_eip.main.public_ip}:8080"
}
