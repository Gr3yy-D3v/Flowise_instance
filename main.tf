provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "Região da AWS"
  default     = "us-east-2"  # Ohio
}

variable "key_name" {
  description = "Nome da chave SSH"
  default     = "flowise-ssh-key"
}

variable "vpc_id" {
  description = "ID da VPC existente (deixe vazio para criar uma nova)"
  default     = ""
}

variable "subnet_id" {
  description = "ID da Subnet existente (deixe vazio para criar uma nova)"
  default     = ""
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Tamanho do volume EBS em GB"
  default     = 20
}

variable "tags" {
  type        = map(string)
  description = "Tags para a instância EC2"
  default     = {}
}

variable "enable_s3_backend" {
  description = "Usar S3/DynamoDB para gerenciamento de estado"
  default     = false
}

variable "s3_bucket" {
  description = "Nome do bucket S3 para o backend"
  default     = ""
}

variable "dynamodb_table" {
  description = "Nome da tabela DynamoDB para o bloqueio do estado"
  default     = ""
}


# Criação de VPC/Subnet apenas se o ID não for fornecido

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge({
    Name = "flowise-vpc"
  }, var.tags)
  count = var.vpc_id == "" ? 1 : 0
}

resource "aws_subnet" "main" {
  vpc_id = coalesce(var.vpc_id, aws_vpc.main.id)
  cidr_block = "10.0.1.0/24"
  availability_zone = var.aws_region == "us-east-2" ? "us-east-2a" : ""
  tags = merge({
    Name = "flowise-subnet"
  }, var.tags)
  count = var.subnet_id == "" ? 1 : 0
}

# Grupo de segurança

resource "aws_security_group" "flowise_sg" {
  vpc_id = coalesce(var.vpc_id, aws_vpc.main.id)

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "flowise-sg"
  }, var.tags)
}

# Backend S3/DynamoDB (Opcional)

terraform {
  backend "s3" {
    bucket         = var.s3_bucket
    key            = "terraform/flowise/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.dynamodb_table
    encrypt        = true
    count          = var.enable_s3_backend ? 1 : 0
  }
}

# Outputs 

output "instance_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.flowise.public_ip
}

output "ssh_private_key" {
  description = "Chave SSH privada"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}
