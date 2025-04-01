resource "aws_rds_cluster" "this" {
  cluster_identifier = var.name
  engine             = "aurora-${var.db_type}"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  storage_type       = var.storage_type
  storage_encrypted  = try(var.encryption.enabled, true)
  kms_key_id         = try(data.aws_kms_key.rds[0].arn, null)

  database_name                       = var.replication_source_identifier != null || try(var.global_cluster.secondary, false) == true ? null : var.db_name
  iam_database_authentication_enabled = try(var.credentials.iam_authentication_enabled, null)

  master_username = local.ignore_admin_credentials ? null : try(var.credentials.master.username, null)
  master_password = local.ignore_admin_credentials ? null : local.database_master_password

  port = local.port

  final_snapshot_identifier = "${var.name}-${random_id.snapshot_identifier.hex}-FINAL"
  skip_final_snapshot       = try(var.maintenance.skip_final_snapshot, null)

  deletion_protection = try(var.maintenance.deletion_protection, false)

  backup_retention_period = try(var.backup.retention_period, null)
  preferred_backup_window = try(var.backup.window, null)
  copy_tags_to_snapshot   = true

  preferred_maintenance_window = try(var.maintenance.window, null)
  apply_immediately            = try(var.maintenance.apply_immediately, false)

  vpc_security_group_ids = concat([aws_security_group.this.id], var.security_groups_additional)

  db_subnet_group_name = var.db_subnet_group_name

  db_cluster_parameter_group_name = var.db_cluster_parameter_group_name

  enabled_cloudwatch_logs_exports = try(var.cloudwatch.exports, null)

  snapshot_identifier           = var.snapshot_identifier
  replication_source_identifier = var.replication_source_identifier

  global_cluster_identifier      = try(var.global_cluster.identifier, null)
  enable_global_write_forwarding = try(var.global_cluster.enable_write_forwarding, null)

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      database_name,
      engine_version,
      global_cluster_identifier,
      iam_roles,
      master_username,
      master_password,
      replication_source_identifier
    ]
  }

  tags = local.tags

  depends_on = [
    aws_cloudwatch_log_group.this
  ]
  provider = aws.this
}
