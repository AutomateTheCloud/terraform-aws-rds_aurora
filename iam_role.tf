# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The role Enhanced Monitoring uses to send the instances' operating system metrics to
# CloudWatch Logs. IAM names are unique in the account, across Regions, so the name is a
# prefix that AWS completes.
resource "aws_iam_role" "monitoring" {
  count = var.instances.monitoring_interval > 0 ? 1 : 0

  name_prefix = "${trimsuffix(substr(var.name, 0, 22), "-")}-rds-monitoring-"
  description = "Enhanced Monitoring for Aurora cluster ${var.name} in ${local.aws.region.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
      # Only for this account's instances.
      Condition = { StringEquals = { "aws:SourceAccount" = local.aws.account.id } }
    }]
  })

  tags = local.tags

  # A new name replaces the role. Creating the new role first lets the instances move to
  # it before the old one is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
