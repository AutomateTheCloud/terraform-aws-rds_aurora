# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Most of the module's options together: two instances, a KMS key of your own, a custom
# parameter group, access from one security group only, IAM database authentication,
# exported logs, Enhanced Monitoring, Performance Insights and Aurora Auto Scaling.

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

data "aws_region" "this" {}

# Amazon S3's address ranges in this Region, for the egress rule. The cluster reaches S3
# through a gateway endpoint in the VPC, or through a NAT gateway.
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.this.region}.s3"
}

resource "aws_db_subnet_group" "this" {
  name       = "example-complete"
  subnet_ids = var.subnet_ids
}

# The application's instances. Only members of this group can reach the database.
resource "aws_security_group" "app" {
  name        = "example-complete-app"
  description = "Application servers that use the orders database"
  vpc_id      = var.vpc_id
}

# Encrypts the cluster's storage, snapshots, Performance Insights data and the
# Secrets Manager secret. The default key policy lets IAM policies in this account
# grant its use.
resource "aws_kms_key" "this" {
  description             = "example-complete database"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "example-complete"
  family      = "aurora-postgresql17"
  description = "Orders database settings"

  # Log every statement that runs for longer than one second.
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

module "aurora" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Orders Database"
    environment = "Production"
    additional_tags = {
      CostCenter = "1234"
    }
  }

  name                            = "example-complete"
  engine                          = "aurora-postgresql"
  engine_version                  = "17.9"
  vpc_id                          = var.vpc_id
  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  database_name                   = "orders"
  master_username                 = "orders_admin"
  kms_key_id                      = aws_kms_key.this.arn
  master_user_secret_kms_key_id   = aws_kms_key.this.arn
  deletion_protection             = var.deletion_protection

  iam_database_authentication_enabled = true

  instances = {
    instance_class               = "db.t3.medium"
    count                        = 2
    monitoring_interval          = 60
    performance_insights_enabled = true
  }

  backup = {
    retention_period = 14
    window           = "03:00-04:00"
  }

  maintenance = {
    window = "sun:05:00-sun:06:00"
  }

  cloudwatch_logs = {
    exports           = ["postgresql", "iam-db-auth-error"]
    retention_in_days = 30
  }

  security_group_ingress = {
    app = { security_group_id = aws_security_group.app.id, description = "Application servers" }
  }

  # Only needed to load data from or save data to Amazon S3, which also needs an IAM
  # role associated with the cluster (aws_rds_cluster_role_association).
  security_group_egress = {
    s3 = { port = 443, prefix_list_id = data.aws_ec2_managed_prefix_list.s3.id, description = "Amazon S3" }
  }

  # One reader from count above, and up to two more when the readers are busy.
  autoscaling = {
    min_capacity           = 1
    max_capacity           = 3
    target_cpu_utilization = 70
  }
}

output "cluster" {
  description = "Where to connect, and the Secrets Manager secret that holds the master password"
  value = {
    endpoint            = module.aurora.metadata.rds_cluster.endpoint
    reader_endpoint     = module.aurora.metadata.rds_cluster.reader_endpoint
    port                = module.aurora.metadata.rds_cluster.port
    master_username     = module.aurora.metadata.rds_cluster.master_username
    secret_arn          = module.aurora.metadata.rds_cluster.master_user_secret[0].secret_arn
    cluster_resource_id = module.aurora.metadata.rds_cluster.cluster_resource_id
    app_security_group  = aws_security_group.app.id
  }
}
