# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.instances.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:${data.aws_partition.this.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"

  lifecycle {
    create_before_destroy = true
  }
}
