# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Test fixture: the network, the client security group, the KMS key and the password are
# created in the same run as the cluster, so their values are not known until apply.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

variable "own_password" {
  type    = bool
  default = false
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "a" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "b" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_db_subnet_group" "this" {
  name       = "same-run"
  subnet_ids = [aws_subnet.a.id, aws_subnet.b.id]
}

resource "aws_security_group" "clients" {
  name        = "clients"
  description = "Clients of the database"
  vpc_id      = aws_vpc.this.id
}

resource "aws_kms_key" "this" {
  enable_key_rotation = true
}

resource "random_password" "master" {
  length  = 24
  special = false
}

module "aurora" {
  source = "../../.."

  details              = { scope = "Test", purpose = "Same Run", environment = "test" }
  name                 = "same-run"
  engine               = "aurora-postgresql"
  vpc_id               = aws_vpc.this.id
  db_subnet_group_name = aws_db_subnet_group.this.name
  kms_key_id           = aws_kms_key.this.arn
  master_password      = var.own_password ? random_password.master.result : null
  instances            = { instance_class = "db.t4g.medium" }
  security_group_ingress = {
    vpc     = { cidr_ipv4 = aws_vpc.this.cidr_block }
    clients = { security_group_id = aws_security_group.clients.id }
  }
  cloudwatch_logs = { exports = ["postgresql"], kms_key_id = aws_kms_key.this.arn }
}

output "metadata" {
  value = module.aurora.metadata
}
