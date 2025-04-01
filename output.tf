output "metadata" {
  description = "Metadata"
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    appautoscaling = {
      target = try(aws_appautoscaling_target.this[0], null)
      policy = {
        scale_on_cpu              = try(aws_appautoscaling_policy.scale_on_cpu[0], null)
        scale_on_connection_count = try(aws_appautoscaling_policy.scale_on_connection_count[0], null)
      }
    }

    cloudwatch = {
      log_group = try(aws_cloudwatch_log_group.this, null)
    }

    iam = {
      role = {
        rds_enhanced_monitoring = try(aws_iam_role.rds_enhanced_monitoring[0], null)
      }
    }
    rds = {
      cluster = {
        allocated_storage                   = try(aws_rds_cluster.this.allocated_storage, null)
        allow_major_version_upgrade         = try(aws_rds_cluster.this.allow_major_version_upgrade, null)
        arn                                 = try(aws_rds_cluster.this.arn, null)
        availability_zones                  = try(aws_rds_cluster.this.availability_zones, null)
        backup_retention_period             = try(aws_rds_cluster.this.backup_retention_period, null)
        cluster_identifier                  = try(aws_rds_cluster.this.cluster_identifier, null)
        cluster_resource_id                 = try(aws_rds_cluster.this.cluster_resource_id, null)
        cluster_members                     = try(aws_rds_cluster.this.cluster_members, null)
        database_name                       = try(aws_rds_cluster.this.database_name, null)
        db_cluster_instance_class           = try(aws_rds_cluster.this.db_cluster_instance_class, null)
        db_cluster_parameter_group_name     = try(aws_rds_cluster.this.db_cluster_parameter_group_name, null)
        db_instance_parameter_group_name    = try(aws_rds_cluster.this.db_instance_parameter_group_name, null)
        db_subnet_group_name                = try(aws_rds_cluster.this.db_subnet_group_name, null)
        enabled_cloudwatch_logs_exports     = try(aws_rds_cluster.this.enabled_cloudwatch_logs_exports, null)
        endpoint                            = try(aws_rds_cluster.this.endpoint, null)
        engine                              = try(aws_rds_cluster.this.engine, null)
        engine_mode                         = try(aws_rds_cluster.this.engine_mode, null)
        engine_version                      = try(aws_rds_cluster.this.engine_version, null)
        global_cluster_identifier           = try(aws_rds_cluster.this.global_cluster_identifier, null)
        hosted_zone_id                      = try(aws_rds_cluster.this.hosted_zone_id, null)
        iam_database_authentication_enabled = try(aws_rds_cluster.this.iam_database_authentication_enabled, null)
        iam_roles                           = try(aws_rds_cluster.this.iam_roles, null)
        id                                  = try(aws_rds_cluster.this.id, null)
        iops                                = try(aws_rds_cluster.this.iops, null)
        kms_key_id                          = try(aws_rds_cluster.this.kms_key_id, null)
        master_username                     = try(aws_rds_cluster.this.master_username, null)
        port                                = try(aws_rds_cluster.this.port, null)
        preferred_backup_window             = try(aws_rds_cluster.this.preferred_backup_window, null)
        preferred_maintenance_window        = try(aws_rds_cluster.this.preferred_maintenance_window, null)
        reader_endpoint                     = try(aws_rds_cluster.this.reader_endpoint, null)
        replication_source_identifier       = try(aws_rds_cluster.this.replication_source_identifier, null)
        scaling_configuration               = try(aws_rds_cluster.this.scaling_configuration, null)
        source_region                       = try(aws_rds_cluster.this.source_region, null)
        storage_encrypted                   = try(aws_rds_cluster.this.storage_encrypted, null)
        storage_type                        = try(aws_rds_cluster.this.storage_type, null)
        tags                                = try(aws_rds_cluster.this.tags, null)
        tags_all                            = try(aws_rds_cluster.this.tags_all, null)
        vpc_security_group_ids              = try(aws_rds_cluster.this.vpc_security_group_ids, null)
      }
      cluster_instance = try(aws_rds_cluster_instance.this[*], null)
    }
    security_group = try(aws_security_group.this, null)
  }
}
