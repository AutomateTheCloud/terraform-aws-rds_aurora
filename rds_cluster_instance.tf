# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_rds_cluster_instance" "this" {
  count = var.instances.count

  region             = var.region
  identifier         = "${var.name}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  instance_class     = var.instances.instance_class

  # The cluster's engine version applies to every instance; it is not set here.
  db_subnet_group_name    = aws_rds_cluster.this.db_subnet_group_name
  db_parameter_group_name = var.db_parameter_group_name
  publicly_accessible     = var.instances.publicly_accessible
  ca_cert_identifier      = var.instances.ca_cert_identifier
  copy_tags_to_snapshot   = true

  # Failover order: the lower the tier, the sooner an instance is promoted.
  promotion_tier = min(count.index, 15)

  monitoring_interval = var.instances.monitoring_interval
  monitoring_role_arn = var.instances.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled          = var.instances.performance_insights_enabled
  performance_insights_kms_key_id       = var.instances.performance_insights_enabled ? var.kms_key_id : null
  performance_insights_retention_period = var.instances.performance_insights_enabled ? var.instances.performance_insights_retention_period : null

  preferred_maintenance_window = var.maintenance.window
  apply_immediately            = var.maintenance.apply_immediately
  auto_minor_version_upgrade   = var.maintenance.auto_minor_version_upgrade

  tags = local.tags

  # The role's policy must be attached before RDS checks it.
  depends_on = [aws_iam_role_policy_attachment.monitoring]
}
