# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An Aurora PostgreSQL cluster with one instance, in private subnets you give, reachable
# from anywhere in the VPC. RDS keeps the master password in AWS Secrets Manager.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to create the cluster in"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets for the cluster, in at least two Availability Zones"
  type        = list(string)
}

variable "deletion_protection" {
  description = "Refuse to delete the cluster. Set it to false and apply before terraform destroy."
  type        = bool
  default     = true
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "this" {
  name       = "example-basic"
  subnet_ids = var.subnet_ids
}

module "aurora" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Orders Database"
    environment = "Development"
  }

  name                 = "example-basic"
  engine               = "aurora-postgresql"
  vpc_id               = var.vpc_id
  db_subnet_group_name = aws_db_subnet_group.this.name
  database_name        = "orders"
  deletion_protection  = var.deletion_protection

  instances = {
    instance_class = "db.t3.medium"
  }

  security_group_ingress = {
    vpc = { cidr_ipv4 = data.aws_vpc.this.cidr_block, description = "Anything in the VPC" }
  }
}

output "cluster" {
  description = "Where to connect, and the Secrets Manager secret that holds the master password"
  value = {
    endpoint        = module.aurora.metadata.rds_cluster.endpoint
    reader_endpoint = module.aurora.metadata.rds_cluster.reader_endpoint
    port            = module.aurora.metadata.rds_cluster.port
    master_username = module.aurora.metadata.rds_cluster.master_username
    secret_arn      = module.aurora.metadata.rds_cluster.master_user_secret[0].secret_arn
  }
}
