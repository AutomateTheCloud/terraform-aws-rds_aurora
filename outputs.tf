# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `rds_cluster` - The cluster's `id`, `arn`, `endpoint` (the writer), `reader_endpoint` (the readers, or the writer when there are none), `port`, `engine`, `engine_version_actual`, `master_username`, `master_user_secret` (a list with the Secrets Manager secret's `secret_arn`, when RDS keeps the password), `cluster_resource_id` (for IAM database authentication policies), `kms_key_id`, `hosted_zone_id` and the rest of its attributes. The instances are in `rds_cluster_instance`, not in a `cluster_members` list.
    - `rds_cluster_instance` - The instances, in order (`<name>-1` first), each with its `identifier`, `endpoint`, `availability_zone`, `writer` (whether it is the writer now), `instance_class`, `dbi_resource_id` and the rest of its attributes.
    - `security_group` - The cluster's security group, with its `id`, `arn` and `name`. Use its `id` as a source in other groups' rules.
    - `vpc_security_group_ingress_rule` - The ingress rules, keyed like `security_group_ingress`, or `null` when there are none.
    - `vpc_security_group_egress_rule` - The egress rules, keyed like `security_group_egress`, or `null` when there are none.
    - `cloudwatch_log_group` - The log groups, keyed by log type, each with its `name` and `arn`, or `null` when no logs are exported.
    - `iam_role` - The Enhanced Monitoring role, with its `name` and `arn`, or `null` when `instances.monitoring_interval` is `0`.
    - `iam_role_policy_attachment` - The attachment of `AmazonRDSEnhancedMonitoringRole` to that role, or `null`.
    - `appautoscaling_target` - The Aurora Auto Scaling target, with its `min_capacity` and `max_capacity`, or `null` without `autoscaling`.
    - `appautoscaling_policy` - The scaling policies, keyed `cpu` and `connections`, or `null` without `autoscaling`.
  EOT
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

    # One entry per resource. Resources that are not created are null.
    appautoscaling_policy           = local.output_resources.appautoscaling_policy
    appautoscaling_target           = local.output_resources.appautoscaling_target
    cloudwatch_log_group            = local.output_resources.cloudwatch_log_group
    iam_role                        = local.output_resources.iam_role
    iam_role_policy_attachment      = local.output_resources.iam_role_policy_attachment
    rds_cluster                     = local.output_resources.rds_cluster
    rds_cluster_instance            = local.output_resources.rds_cluster_instance
    security_group                  = local.output_resources.security_group
    vpc_security_group_egress_rule  = local.output_resources.vpc_security_group_egress_rule
    vpc_security_group_ingress_rule = local.output_resources.vpc_security_group_ingress_rule
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource, or
  # iterating over it, would also reference its deprecated and sensitive attributes, and
  # every caller's plan would print deprecation warnings or the output would turn
  # sensitive. Generated with output-attributes.py from the provider schemas.
  #
  # Left out: the cluster's cluster_members, which is saved before the instances join it
  # and filled in on the next refresh, so every caller's second plan would show it
  # changing; the instances are in rds_cluster_instance. Its
  # enabled_cloudwatch_logs_exports, which a restore from a snapshot saves as null and
  # reads back as []; the log groups are in cloudwatch_log_group. The security group's inline
  # ingress and egress, for the same reason; the rule resources are output instead. A
  # scaling policy's alarm_arns, which Application Auto Scaling replaces whenever the
  # capacity changes.
  output_resources = {
    appautoscaling_policy = length(local.autoscaling_policies) == 0 ? null : {
      for k in keys(local.autoscaling_policies) : k => {
        arn                                          = aws_appautoscaling_policy.this[k].arn
        id                                           = aws_appautoscaling_policy.this[k].id
        name                                         = aws_appautoscaling_policy.this[k].name
        policy_type                                  = aws_appautoscaling_policy.this[k].policy_type
        region                                       = aws_appautoscaling_policy.this[k].region
        resource_id                                  = aws_appautoscaling_policy.this[k].resource_id
        scalable_dimension                           = aws_appautoscaling_policy.this[k].scalable_dimension
        service_namespace                            = aws_appautoscaling_policy.this[k].service_namespace
        step_scaling_policy_configuration            = aws_appautoscaling_policy.this[k].step_scaling_policy_configuration
        target_tracking_scaling_policy_configuration = aws_appautoscaling_policy.this[k].target_tracking_scaling_policy_configuration
      }
    }

    appautoscaling_target = var.autoscaling == null ? null : {
      arn                = aws_appautoscaling_target.this[0].arn
      id                 = aws_appautoscaling_target.this[0].id
      max_capacity       = aws_appautoscaling_target.this[0].max_capacity
      min_capacity       = aws_appautoscaling_target.this[0].min_capacity
      region             = aws_appautoscaling_target.this[0].region
      resource_id        = aws_appautoscaling_target.this[0].resource_id
      role_arn           = aws_appautoscaling_target.this[0].role_arn
      scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
      service_namespace  = aws_appautoscaling_target.this[0].service_namespace
      suspended_state    = aws_appautoscaling_target.this[0].suspended_state
      tags               = aws_appautoscaling_target.this[0].tags
      tags_all           = aws_appautoscaling_target.this[0].tags_all
    }

    cloudwatch_log_group = length(var.cloudwatch_logs.exports) == 0 ? null : {
      for k in var.cloudwatch_logs.exports : k => {
        arn               = aws_cloudwatch_log_group.this[k].arn
        id                = aws_cloudwatch_log_group.this[k].id
        kms_key_id        = aws_cloudwatch_log_group.this[k].kms_key_id
        log_group_class   = aws_cloudwatch_log_group.this[k].log_group_class
        name              = aws_cloudwatch_log_group.this[k].name
        name_prefix       = aws_cloudwatch_log_group.this[k].name_prefix
        region            = aws_cloudwatch_log_group.this[k].region
        retention_in_days = aws_cloudwatch_log_group.this[k].retention_in_days
        skip_destroy      = aws_cloudwatch_log_group.this[k].skip_destroy
        tags              = aws_cloudwatch_log_group.this[k].tags
        tags_all          = aws_cloudwatch_log_group.this[k].tags_all
      }
    }

    iam_role = var.instances.monitoring_interval == 0 ? null : {
      arn                   = aws_iam_role.monitoring[0].arn
      assume_role_policy    = aws_iam_role.monitoring[0].assume_role_policy
      create_date           = aws_iam_role.monitoring[0].create_date
      description           = aws_iam_role.monitoring[0].description
      force_detach_policies = aws_iam_role.monitoring[0].force_detach_policies
      id                    = aws_iam_role.monitoring[0].id
      max_session_duration  = aws_iam_role.monitoring[0].max_session_duration
      name                  = aws_iam_role.monitoring[0].name
      name_prefix           = aws_iam_role.monitoring[0].name_prefix
      path                  = aws_iam_role.monitoring[0].path
      permissions_boundary  = aws_iam_role.monitoring[0].permissions_boundary
      tags                  = aws_iam_role.monitoring[0].tags
      tags_all              = aws_iam_role.monitoring[0].tags_all
      unique_id             = aws_iam_role.monitoring[0].unique_id
    }

    iam_role_policy_attachment = var.instances.monitoring_interval == 0 ? null : {
      id         = aws_iam_role_policy_attachment.monitoring[0].id
      policy_arn = aws_iam_role_policy_attachment.monitoring[0].policy_arn
      role       = aws_iam_role_policy_attachment.monitoring[0].role
    }

    rds_cluster = {
      allocated_storage                     = aws_rds_cluster.this.allocated_storage
      allow_major_version_upgrade           = aws_rds_cluster.this.allow_major_version_upgrade
      apply_immediately                     = aws_rds_cluster.this.apply_immediately
      arn                                   = aws_rds_cluster.this.arn
      availability_zones                    = aws_rds_cluster.this.availability_zones
      backtrack_window                      = aws_rds_cluster.this.backtrack_window
      backup_retention_period               = aws_rds_cluster.this.backup_retention_period
      ca_certificate_identifier             = aws_rds_cluster.this.ca_certificate_identifier
      ca_certificate_valid_till             = aws_rds_cluster.this.ca_certificate_valid_till
      cluster_identifier                    = aws_rds_cluster.this.cluster_identifier
      cluster_identifier_prefix             = aws_rds_cluster.this.cluster_identifier_prefix
      cluster_resource_id                   = aws_rds_cluster.this.cluster_resource_id
      cluster_scalability_type              = aws_rds_cluster.this.cluster_scalability_type
      copy_tags_to_snapshot                 = aws_rds_cluster.this.copy_tags_to_snapshot
      database_insights_mode                = aws_rds_cluster.this.database_insights_mode
      database_name                         = aws_rds_cluster.this.database_name
      db_cluster_instance_class             = aws_rds_cluster.this.db_cluster_instance_class
      db_cluster_parameter_group_name       = aws_rds_cluster.this.db_cluster_parameter_group_name
      db_instance_parameter_group_name      = aws_rds_cluster.this.db_instance_parameter_group_name
      db_subnet_group_name                  = aws_rds_cluster.this.db_subnet_group_name
      db_system_id                          = aws_rds_cluster.this.db_system_id
      delete_automated_backups              = aws_rds_cluster.this.delete_automated_backups
      deletion_protection                   = aws_rds_cluster.this.deletion_protection
      domain                                = aws_rds_cluster.this.domain
      domain_iam_role_name                  = aws_rds_cluster.this.domain_iam_role_name
      enable_global_write_forwarding        = aws_rds_cluster.this.enable_global_write_forwarding
      enable_http_endpoint                  = aws_rds_cluster.this.enable_http_endpoint
      enable_local_write_forwarding         = aws_rds_cluster.this.enable_local_write_forwarding
      endpoint                              = aws_rds_cluster.this.endpoint
      engine                                = aws_rds_cluster.this.engine
      engine_lifecycle_support              = aws_rds_cluster.this.engine_lifecycle_support
      engine_mode                           = aws_rds_cluster.this.engine_mode
      engine_version                        = aws_rds_cluster.this.engine_version
      engine_version_actual                 = aws_rds_cluster.this.engine_version_actual
      final_snapshot_identifier             = aws_rds_cluster.this.final_snapshot_identifier
      global_cluster_identifier             = aws_rds_cluster.this.global_cluster_identifier
      hosted_zone_id                        = aws_rds_cluster.this.hosted_zone_id
      iam_database_authentication_enabled   = aws_rds_cluster.this.iam_database_authentication_enabled
      iam_roles                             = aws_rds_cluster.this.iam_roles
      id                                    = aws_rds_cluster.this.id
      iops                                  = aws_rds_cluster.this.iops
      kms_key_id                            = aws_rds_cluster.this.kms_key_id
      manage_master_user_password           = aws_rds_cluster.this.manage_master_user_password
      master_password_wo_version            = aws_rds_cluster.this.master_password_wo_version
      master_user_secret                    = aws_rds_cluster.this.master_user_secret
      master_user_secret_kms_key_id         = aws_rds_cluster.this.master_user_secret_kms_key_id
      master_username                       = aws_rds_cluster.this.master_username
      monitoring_interval                   = aws_rds_cluster.this.monitoring_interval
      monitoring_role_arn                   = aws_rds_cluster.this.monitoring_role_arn
      network_type                          = aws_rds_cluster.this.network_type
      performance_insights_enabled          = aws_rds_cluster.this.performance_insights_enabled
      performance_insights_kms_key_id       = aws_rds_cluster.this.performance_insights_kms_key_id
      performance_insights_retention_period = aws_rds_cluster.this.performance_insights_retention_period
      port                                  = aws_rds_cluster.this.port
      preferred_backup_window               = aws_rds_cluster.this.preferred_backup_window
      preferred_maintenance_window          = aws_rds_cluster.this.preferred_maintenance_window
      reader_endpoint                       = aws_rds_cluster.this.reader_endpoint
      region                                = aws_rds_cluster.this.region
      replication_source_identifier         = aws_rds_cluster.this.replication_source_identifier
      restore_to_point_in_time              = aws_rds_cluster.this.restore_to_point_in_time
      s3_import                             = aws_rds_cluster.this.s3_import
      scaling_configuration                 = aws_rds_cluster.this.scaling_configuration
      serverlessv2_scaling_configuration    = aws_rds_cluster.this.serverlessv2_scaling_configuration
      skip_final_snapshot                   = aws_rds_cluster.this.skip_final_snapshot
      snapshot_identifier                   = aws_rds_cluster.this.snapshot_identifier
      source_region                         = aws_rds_cluster.this.source_region
      storage_encrypted                     = aws_rds_cluster.this.storage_encrypted
      storage_type                          = aws_rds_cluster.this.storage_type
      tags                                  = aws_rds_cluster.this.tags
      tags_all                              = aws_rds_cluster.this.tags_all
      vpc_security_group_ids                = aws_rds_cluster.this.vpc_security_group_ids
    }

    rds_cluster_instance = [
      for i in range(var.instances.count) : {
        apply_immediately                     = aws_rds_cluster_instance.this[i].apply_immediately
        arn                                   = aws_rds_cluster_instance.this[i].arn
        auto_minor_version_upgrade            = aws_rds_cluster_instance.this[i].auto_minor_version_upgrade
        availability_zone                     = aws_rds_cluster_instance.this[i].availability_zone
        ca_cert_identifier                    = aws_rds_cluster_instance.this[i].ca_cert_identifier
        cluster_identifier                    = aws_rds_cluster_instance.this[i].cluster_identifier
        copy_tags_to_snapshot                 = aws_rds_cluster_instance.this[i].copy_tags_to_snapshot
        custom_iam_instance_profile           = aws_rds_cluster_instance.this[i].custom_iam_instance_profile
        db_parameter_group_name               = aws_rds_cluster_instance.this[i].db_parameter_group_name
        db_subnet_group_name                  = aws_rds_cluster_instance.this[i].db_subnet_group_name
        dbi_resource_id                       = aws_rds_cluster_instance.this[i].dbi_resource_id
        endpoint                              = aws_rds_cluster_instance.this[i].endpoint
        engine                                = aws_rds_cluster_instance.this[i].engine
        engine_version                        = aws_rds_cluster_instance.this[i].engine_version
        engine_version_actual                 = aws_rds_cluster_instance.this[i].engine_version_actual
        force_destroy                         = aws_rds_cluster_instance.this[i].force_destroy
        id                                    = aws_rds_cluster_instance.this[i].id
        identifier                            = aws_rds_cluster_instance.this[i].identifier
        identifier_prefix                     = aws_rds_cluster_instance.this[i].identifier_prefix
        instance_class                        = aws_rds_cluster_instance.this[i].instance_class
        kms_key_id                            = aws_rds_cluster_instance.this[i].kms_key_id
        monitoring_interval                   = aws_rds_cluster_instance.this[i].monitoring_interval
        monitoring_role_arn                   = aws_rds_cluster_instance.this[i].monitoring_role_arn
        network_type                          = aws_rds_cluster_instance.this[i].network_type
        performance_insights_enabled          = aws_rds_cluster_instance.this[i].performance_insights_enabled
        performance_insights_kms_key_id       = aws_rds_cluster_instance.this[i].performance_insights_kms_key_id
        performance_insights_retention_period = aws_rds_cluster_instance.this[i].performance_insights_retention_period
        port                                  = aws_rds_cluster_instance.this[i].port
        preferred_backup_window               = aws_rds_cluster_instance.this[i].preferred_backup_window
        preferred_maintenance_window          = aws_rds_cluster_instance.this[i].preferred_maintenance_window
        promotion_tier                        = aws_rds_cluster_instance.this[i].promotion_tier
        publicly_accessible                   = aws_rds_cluster_instance.this[i].publicly_accessible
        region                                = aws_rds_cluster_instance.this[i].region
        storage_encrypted                     = aws_rds_cluster_instance.this[i].storage_encrypted
        tags                                  = aws_rds_cluster_instance.this[i].tags
        tags_all                              = aws_rds_cluster_instance.this[i].tags_all
        writer                                = aws_rds_cluster_instance.this[i].writer
      }
    ]

    security_group = {
      arn                    = aws_security_group.this.arn
      description            = aws_security_group.this.description
      id                     = aws_security_group.this.id
      name                   = aws_security_group.this.name
      name_prefix            = aws_security_group.this.name_prefix
      owner_id               = aws_security_group.this.owner_id
      region                 = aws_security_group.this.region
      revoke_rules_on_delete = aws_security_group.this.revoke_rules_on_delete
      tags                   = aws_security_group.this.tags
      tags_all               = aws_security_group.this.tags_all
      vpc_id                 = aws_security_group.this.vpc_id
    }

    vpc_security_group_egress_rule = length(var.security_group_egress) == 0 ? null : {
      for k in keys(var.security_group_egress) : k => {
        arn                          = aws_vpc_security_group_egress_rule.this[k].arn
        cidr_ipv4                    = aws_vpc_security_group_egress_rule.this[k].cidr_ipv4
        cidr_ipv6                    = aws_vpc_security_group_egress_rule.this[k].cidr_ipv6
        description                  = aws_vpc_security_group_egress_rule.this[k].description
        from_port                    = aws_vpc_security_group_egress_rule.this[k].from_port
        id                           = aws_vpc_security_group_egress_rule.this[k].id
        ip_protocol                  = aws_vpc_security_group_egress_rule.this[k].ip_protocol
        prefix_list_id               = aws_vpc_security_group_egress_rule.this[k].prefix_list_id
        referenced_security_group_id = aws_vpc_security_group_egress_rule.this[k].referenced_security_group_id
        region                       = aws_vpc_security_group_egress_rule.this[k].region
        security_group_id            = aws_vpc_security_group_egress_rule.this[k].security_group_id
        security_group_rule_id       = aws_vpc_security_group_egress_rule.this[k].security_group_rule_id
        tags                         = aws_vpc_security_group_egress_rule.this[k].tags
        tags_all                     = aws_vpc_security_group_egress_rule.this[k].tags_all
        to_port                      = aws_vpc_security_group_egress_rule.this[k].to_port
      }
    }

    vpc_security_group_ingress_rule = length(var.security_group_ingress) == 0 ? null : {
      for k in keys(var.security_group_ingress) : k => {
        arn                          = aws_vpc_security_group_ingress_rule.this[k].arn
        cidr_ipv4                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv4
        cidr_ipv6                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv6
        description                  = aws_vpc_security_group_ingress_rule.this[k].description
        from_port                    = aws_vpc_security_group_ingress_rule.this[k].from_port
        id                           = aws_vpc_security_group_ingress_rule.this[k].id
        ip_protocol                  = aws_vpc_security_group_ingress_rule.this[k].ip_protocol
        prefix_list_id               = aws_vpc_security_group_ingress_rule.this[k].prefix_list_id
        referenced_security_group_id = aws_vpc_security_group_ingress_rule.this[k].referenced_security_group_id
        region                       = aws_vpc_security_group_ingress_rule.this[k].region
        security_group_id            = aws_vpc_security_group_ingress_rule.this[k].security_group_id
        security_group_rule_id       = aws_vpc_security_group_ingress_rule.this[k].security_group_rule_id
        tags                         = aws_vpc_security_group_ingress_rule.this[k].tags
        tags_all                     = aws_vpc_security_group_ingress_rule.this[k].tags_all
        to_port                      = aws_vpc_security_group_ingress_rule.this[k].to_port
      }
    }
  }
}
