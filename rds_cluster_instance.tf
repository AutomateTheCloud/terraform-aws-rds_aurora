resource "aws_rds_cluster_instance" "this" {
  count                           = try(var.instance.count, 1)
  identifier                      = "${var.name}-${count.index + 1}"
  cluster_identifier              = aws_rds_cluster.this.id
  engine                          = "aurora-${var.db_type}"
  engine_version                  = var.engine_version
  instance_class                  = try(var.instance.class, null)
  publicly_accessible             = try(var.instance.public, false)
  db_subnet_group_name            = var.db_subnet_group_name
  db_parameter_group_name         = var.db_parameter_group_name
  preferred_maintenance_window    = try(var.maintenance.window, null)
  apply_immediately               = try(var.maintenance.apply_immediately, false)
  monitoring_role_arn             = (var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null)
  monitoring_interval             = var.monitoring_interval
  auto_minor_version_upgrade      = try(var.maintenance.auto_minor_version_upgrade, null)
  promotion_tier                  = count.index + 1
  performance_insights_enabled    = try(var.performance_insights.enabled, true)
  performance_insights_kms_key_id = try(var.performance_insights.enabled, true) ? try(data.aws_kms_key.rds[0].arn, null) : null
  ca_cert_identifier              = var.ca_cert_identifier
  lifecycle {
    ignore_changes = [
      cluster_identifier,
      engine_version
    ]
  }
  tags     = local.tags
  provider = aws.this
}
