# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0", arn = "arn:aws:ec2:us-east-1:111111111111:security-group/sg-0123456789abcdef0" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/orders-rds-monitoring-1" }
  }
  mock_resource "aws_rds_cluster" {
    defaults = { arn = "arn:aws:rds:us-east-1:111111111111:cluster:orders", id = "orders" }
  }
}

variables {
  details              = { scope = "Test", purpose = "Orders Database", environment = "test" }
  name                 = "orders"
  engine               = "aurora-postgresql"
  vpc_id               = "vpc-0123456789abcdef0"
  db_subnet_group_name = "private"
  instances            = { instance_class = "db.t4g.medium" }
}

run "own_password" {
  command = plan
  variables {
    master_password = "correct-horse-battery"
  }
  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password == null && nonsensitive(aws_rds_cluster.this.master_password == "correct-horse-battery")
    error_message = "A password of the caller's own replaces the Secrets Manager secret."
  }
}

run "autoscaling_cpu_only" {
  command = plan
  variables {
    autoscaling = { max_capacity = 2, target_cpu_utilization = 60 }
  }
  assert {
    condition     = toset(keys(aws_appautoscaling_policy.this)) == toset(["cpu"]) && aws_appautoscaling_target.this[0].min_capacity == 1
    error_message = "Only the CPU policy expected."
  }
}

run "global_primary" {
  command = plan
  variables {
    global_cluster = { identifier = "orders-global" }
    database_name  = "orders"
  }
  assert {
    condition     = aws_rds_cluster.this.global_cluster_identifier == "orders-global" && aws_rds_cluster.this.database_name == "orders" && aws_rds_cluster.this.master_username == "postgres" && aws_rds_cluster.this.manage_master_user_password == true && aws_rds_cluster.this.enable_global_write_forwarding == null
    error_message = "A global primary is created like a standalone cluster."
  }
}

run "global_secondary" {
  command = plan
  variables {
    region         = "us-west-2"
    kms_key_id     = "arn:aws:kms:us-west-2:111111111111:key/data"
    global_cluster = { identifier = "orders-global", secondary = true, enable_write_forwarding = true }
  }
  assert {
    condition     = aws_rds_cluster.this.global_cluster_identifier == "orders-global" && aws_rds_cluster.this.enable_global_write_forwarding == true
    error_message = "Unexpected global secondary settings."
  }
  assert {
    condition     = nonsensitive(aws_rds_cluster.this.master_password == null) && aws_rds_cluster.this.manage_master_user_password == null
    error_message = "A global secondary takes no master password settings; database_name and master_username are left unset (unknown at plan)."
  }
}

run "snapshot_restore" {
  command = plan
  variables {
    snapshot_identifier = "orders-final-0a1b2c3d"
  }
  assert {
    condition     = aws_rds_cluster.this.snapshot_identifier == "orders-final-0a1b2c3d" && aws_rds_cluster.this.manage_master_user_password == true
    error_message = "Unexpected restore settings."
  }
}

run "public_instances_opt_in" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", publicly_accessible = true }
  }
  assert {
    condition     = aws_rds_cluster_instance.this[0].publicly_accessible == true
    error_message = "publicly_accessible must reach the instances."
  }
}

run "most_options" {
  command = apply
  variables {
    engine_version                      = "17.9"
    database_name                       = "orders"
    master_username                     = "owner"
    master_user_secret_kms_key_id       = "arn:aws:kms:us-east-1:111111111111:key/secret"
    kms_key_id                          = "arn:aws:kms:us-east-1:111111111111:key/data"
    port                                = 6543
    iam_database_authentication_enabled = true
    storage_type                        = "aurora-iopt1"
    db_cluster_parameter_group_name     = "orders-cluster"
    db_parameter_group_name             = "orders-instance"
    security_group_ids                  = ["sg-0000000000000000b"]
    deletion_protection                 = false
    skip_final_snapshot                 = true
    instances = {
      instance_class                        = "db.r6g.large"
      count                                 = 3
      ca_cert_identifier                    = "rds-ca-rsa2048-g1"
      monitoring_interval                   = 15
      performance_insights_enabled          = true
      performance_insights_retention_period = 31
    }
    backup          = { retention_period = 14, window = "04:00-05:00" }
    maintenance     = { window = "sun:06:00-sun:07:00", apply_immediately = true, auto_minor_version_upgrade = false, allow_major_version_upgrade = true }
    cloudwatch_logs = { exports = ["postgresql", "iam-db-auth-error"], retention_in_days = 30, kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/logs" }
    security_group_ingress = {
      app    = { security_group_id = "sg-0000000000000000a", description = "Application servers" }
      office = { cidr_ipv4 = "10.0.0.0/16" }
      ipv6   = { cidr_ipv6 = "2001:db8::/56" }
      vpn    = { prefix_list_id = "pl-0123456789abcdef0" }
    }
    security_group_egress = {
      s3 = { port = 443, prefix_list_id = "pl-63a5400a" }
    }
    autoscaling = { min_capacity = 2, max_capacity = 5, target_cpu_utilization = 70, target_connections = 500, scale_in_cooldown = 600 }
    timeouts    = { create = "3h" }
  }

  assert {
    condition     = aws_rds_cluster.this.kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/data" && aws_rds_cluster_instance.this[0].performance_insights_kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/data" && aws_rds_cluster_instance.this[2].performance_insights_retention_period == 31
    error_message = "The KMS key must encrypt storage and Performance Insights."
  }
  assert {
    condition     = aws_rds_cluster.this.master_username == "owner" && aws_rds_cluster.this.master_user_secret_kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/secret" && aws_rds_cluster.this.database_name == "orders"
    error_message = "Unexpected master user or database."
  }
  assert {
    condition     = aws_rds_cluster.this.engine_version == "17.9" && aws_rds_cluster.this.storage_type == "aurora-iopt1" && aws_rds_cluster.this.port == 6543 && aws_rds_cluster.this.iam_database_authentication_enabled
    error_message = "Unexpected cluster settings."
  }
  assert {
    condition     = aws_rds_cluster.this.vpc_security_group_ids == toset(["sg-0123456789abcdef0", "sg-0000000000000000b"])
    error_message = "Extra security groups must be attached beside the module's own."
  }
  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.this)) == toset(["app", "office", "ipv6", "vpn"]) && alltrue([for r in aws_vpc_security_group_ingress_rule.this : r.from_port == 6543 && r.to_port == 6543 && r.ip_protocol == "tcp"])
    error_message = "Ingress must allow only the database port from each source."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["app"].referenced_security_group_id == "sg-0000000000000000a" && aws_vpc_security_group_ingress_rule.this["app"].description == "Application servers" && aws_vpc_security_group_ingress_rule.this["office"].description == "office"
    error_message = "Unexpected ingress rule sources or descriptions."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.this["s3"].prefix_list_id == "pl-63a5400a" && aws_vpc_security_group_egress_rule.this["s3"].from_port == 443
    error_message = "Unexpected egress rule."
  }
  assert {
    condition     = length(aws_rds_cluster_instance.this) == 3 && aws_rds_cluster_instance.this[2].identifier == "orders-3" && aws_rds_cluster_instance.this[2].promotion_tier == 2 && aws_rds_cluster_instance.this[1].instance_class == "db.r6g.large"
    error_message = "Unexpected instances."
  }
  assert {
    condition     = aws_rds_cluster_instance.this[0].monitoring_role_arn == aws_iam_role.monitoring[0].arn && startswith(aws_iam_role.monitoring[0].name_prefix, "orders-rds-monitoring-") && aws_iam_role_policy_attachment.monitoring[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
    error_message = "Enhanced Monitoring must use the module's role."
  }
  assert {
    condition     = jsondecode(aws_iam_role.monitoring[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "111111111111"
    error_message = "The monitoring role must trust RDS only for this account."
  }
  assert {
    condition     = toset(keys(aws_cloudwatch_log_group.this)) == toset(["postgresql", "iam-db-auth-error"]) && aws_cloudwatch_log_group.this["postgresql"].name == "/aws/rds/cluster/orders/postgresql" && aws_cloudwatch_log_group.this["postgresql"].retention_in_days == 30 && aws_cloudwatch_log_group.this["postgresql"].kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/logs"
    error_message = "Unexpected log groups."
  }
  assert {
    condition     = aws_rds_cluster.this.enabled_cloudwatch_logs_exports == toset(["iam-db-auth-error", "postgresql"])
    error_message = "The cluster must export the log types."
  }
  assert {
    condition     = aws_appautoscaling_target.this[0].min_capacity == 2 && aws_appautoscaling_target.this[0].max_capacity == 5 && aws_appautoscaling_target.this[0].resource_id == "cluster:orders"
    error_message = "Unexpected Auto Scaling target."
  }
  assert {
    condition     = toset(keys(aws_appautoscaling_policy.this)) == toset(["cpu", "connections"]) && aws_appautoscaling_policy.this["cpu"].target_tracking_scaling_policy_configuration[0].target_value == 70 && aws_appautoscaling_policy.this["connections"].target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 600
    error_message = "Unexpected Auto Scaling policies."
  }
  assert {
    condition     = aws_rds_cluster.this.preferred_backup_window == "04:00-05:00" && aws_rds_cluster.this.backup_retention_period == 14 && aws_rds_cluster_instance.this[0].preferred_maintenance_window == "sun:06:00-sun:07:00" && aws_rds_cluster_instance.this[0].auto_minor_version_upgrade == false && aws_rds_cluster.this.allow_major_version_upgrade
    error_message = "Unexpected backup or maintenance settings."
  }
  assert {
    condition     = length(output.metadata.vpc_security_group_ingress_rule) == 4 && output.metadata.cloudwatch_log_group["postgresql"].retention_in_days == 30 && output.metadata.appautoscaling_policy["cpu"].policy_type == "TargetTrackingScaling" && output.metadata.iam_role.arn == aws_iam_role.monitoring[0].arn && output.metadata.rds_cluster_instance[2].identifier == "orders-3"
    error_message = "Unexpected metadata output."
  }
}
