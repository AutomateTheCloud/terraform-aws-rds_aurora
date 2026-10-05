# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_rds_cluster" "this" {
  region             = var.region
  cluster_identifier = var.name
  engine             = var.engine
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  storage_type       = var.storage_type
  storage_encrypted  = true
  kms_key_id         = var.kms_key_id
  port               = local.port

  database_name                       = local.secondary ? null : var.database_name
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  master_username               = local.secondary ? null : local.master_username
  master_password               = local.secondary ? null : var.master_password
  manage_master_user_password   = local.manage_master_user_password ? true : null
  master_user_secret_kms_key_id = local.manage_master_user_password ? var.master_user_secret_kms_key_id : null

  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = concat([aws_security_group.this.id], var.security_group_ids)
  db_cluster_parameter_group_name = var.db_cluster_parameter_group_name

  backup_retention_period   = var.backup.retention_period
  preferred_backup_window   = var.backup.window
  copy_tags_to_snapshot     = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.name}-final-${random_id.final_snapshot.hex}"

  preferred_maintenance_window = var.maintenance.window
  apply_immediately            = var.maintenance.apply_immediately
  allow_major_version_upgrade  = var.maintenance.allow_major_version_upgrade

  # An empty list, not null: the provider reads an unset list back as [].
  enabled_cloudwatch_logs_exports = sort(tolist(var.cloudwatch_logs.exports))

  snapshot_identifier            = var.snapshot_identifier
  global_cluster_identifier      = try(var.global_cluster.identifier, null)
  enable_global_write_forwarding = local.secondary ? var.global_cluster.enable_write_forwarding : null

  tags = local.tags

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    # Used only when the cluster is created. A restore from a snapshot or a global
    # secondary gets these from its source, and changing them would replace the cluster.
    # iam_roles is left to aws_rds_cluster_role_association resources outside the module,
    # and AWS sets replication_source_identifier on a global secondary.
    ignore_changes = [
      database_name,
      global_cluster_identifier,
      iam_roles,
      master_username,
      replication_source_identifier,
      snapshot_identifier,
    ]
  }

  # The log groups exist before RDS writes to them, so their retention and key apply.
  depends_on = [aws_cloudwatch_log_group.this]
}
