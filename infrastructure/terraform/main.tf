# implement Terraform infrastructure
# Created: 2026-05-08 22:11:20
# Terraform configuration for AI DevOps Assistant

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Configuration
resource "aws_vpc" "ai_devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "ai-devops-vpc-${var.environment}"
    Environment = var.environment
    Component   = "feat"
    CreatedBy   = "terraform"
    Purpose     = "implement Terraform infrastructure"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ai_devops_igw" {
  vpc_id = aws_vpc.ai_devops_vpc.id

  tags = {
    Name        = "ai-devops-igw-${var.environment}"
    Environment = var.environment
  }
}

# Subnets
resource "aws_subnet" "ai_devops_public" {
  count = 2

  vpc_id                  = aws_vpc.ai_devops_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "ai-devops-public-${count.index + 1}-${var.environment}"
    Environment = var.environment
    Type        = "public"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "ai_devops_cluster" {
  name     = "ai-devops-${var.environment}"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = aws_subnet.ai_devops_public[*].id

    endpoint_config {
      private_access = true
      public_access  = true
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name        = "ai-devops-cluster-${var.environment}"
    Environment = var.environment
    Purpose     = "implement Terraform infrastructure"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "ai-devops-eks-cluster-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# Outputs
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.ai_devops_cluster.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.ai_devops_cluster.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.ai_devops_vpc.id
}
