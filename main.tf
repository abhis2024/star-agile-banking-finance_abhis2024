terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# AWS Key Pair (Avoids re-importing if the key already exists)
resource "aws_key_pair" "example" {
  key_name   = "project-key"
  public_key = file("~/.ssh/id_ed25519.pub")
  }

# AWS Security Group allowing all traffic
resource "aws_security_group" "allow_all" {
  name_prefix = "allow_all"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # This allows all protocols (TCP, UDP, ICMP)
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # This allows all protocols (TCP, UDP, ICMP)
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance Creation
resource "aws_instance" "server" {
  ami           = "ami-0e86e20dae9224db8"
  instance_type = var.instance_type
  key_name      = "project-key"
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  tags = {
    Name = "${terraform.workspace}_server"
  }

  # Execute remote commands after instance creation
  provisioner "remote-exec" {
    inline = [
      "cat /etc/os-release",
      "mkdir -p /home/ubuntu/.ssh",
      "echo '${var.ssh_public_key}' >> /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]
  }

  # SSH connection configuration
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
  }

  # Create the inventory file for Ansible
  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_private_key_file=~/.ssh/id_ed25519' > inventory.ini"
  }

  # Run the Ansible playbook after the instance is created
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i inventory.ini -e 'ansible_python_interpreter=/usr/bin/python3' ansible-playbook.yml"
  }
}

