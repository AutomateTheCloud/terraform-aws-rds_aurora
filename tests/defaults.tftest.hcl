# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
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

# Optional and computed arguments are unknown at plan when left unset, and a mocked apply
# fills them with made-up values, so "left to AWS" is checked against the configuration.
run "keys_left_to_aws" {
  command = plan
  assert {
    condition     = aws_rds_cluster.this.storage_encrypted == true && aws_rds_cluster.this.manage_master_user_password == true
    error_message = "Encrypted storage and a Secrets Manager password expected."
  }
  # Empty, not null: the provider reads an unset list back as an empty one, and every
  # plan after an apply would show a change.
  assert {
    condition     = aws_rds_cluster.this.enabled_cloudwatch_logs_exports != null && length(aws_rds_cluster.this.enabled_cloudwatch_logs_exports) == 0
    error_message = "No logs are exported by default, and the list must be empty, not null."
  }
}

run "mysql_defaults" {
  command = plan
  variables {
    engine = "aurora-mysql"
  }
  assert {
    condition     = aws_rds_cluster.this.port == 3306 && aws_rds_cluster.this.master_username == "admin"
    error_message = "Unexpected engine defaults for aurora-mysql."
  }
}

run "abbreviation_override" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Orders Database", environment = "Production", environment_abbr = "prd", additional_tags = { CostCenter = "1234" } }
  }
  assert {
    condition     = output.metadata.details.environment.abbr == "prd" && output.metadata.details.purpose.machine == "ordersdatabase" && aws_rds_cluster.this.tags["CostCenter"] == "1234"
    error_message = "Unexpected details handling."
  }
}

run "details_scope_required" {
  command = plan
  variables {
    details = { scope = " ", purpose = "P", environment = "E" }
  }
  expect_failures = [var.details]
}

run "details_purpose_required" {
  command = plan
  variables {
    details = { scope = "S", purpose = "", environment = "E" }
  }
  expect_failures = [var.details]
}

run "details_environment_required" {
  command = plan
  variables {
    details = { scope = "S", purpose = "P", environment = "" }
  }
  expect_failures = [var.details]
}

run "defaults_are_secure" {
  command = apply

  assert {
    condition     = aws_rds_cluster.this.storage_encrypted == true
    error_message = "The cluster must be encrypted."
  }
  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password == true && nonsensitive(aws_rds_cluster.this.master_password == null)
    error_message = "RDS must keep the master password in Secrets Manager by default."
  }
  assert {
    condition     = aws_rds_cluster.this.deletion_protection == true && aws_rds_cluster.this.skip_final_snapshot == false && startswith(aws_rds_cluster.this.final_snapshot_identifier, "orders-final-")
    error_message = "Deletion protection and a final snapshot must be on by default."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0 && length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "No network access may be allowed by default, in or out."
  }
  assert {
    condition     = aws_rds_cluster_instance.this[0].publicly_accessible == false && length(aws_rds_cluster_instance.this) == 1
    error_message = "One private instance expected by default."
  }
  assert {
    condition     = aws_rds_cluster.this.iam_database_authentication_enabled == false && aws_rds_cluster.this.copy_tags_to_snapshot == true && aws_rds_cluster.this.backup_retention_period == 7
    error_message = "Unexpected cluster defaults."
  }
  assert {
    condition     = aws_rds_cluster.this.port == 5432 && aws_rds_cluster.this.master_username == "postgres" && aws_rds_cluster.this.engine_mode == "provisioned"
    error_message = "Unexpected engine defaults for aurora-postgresql."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "No log groups by default."
  }
  assert {
    condition     = length(aws_iam_role.monitoring) == 0 && aws_rds_cluster_instance.this[0].monitoring_interval == 0 && aws_rds_cluster_instance.this[0].performance_insights_enabled == false
    error_message = "Enhanced Monitoring and Performance Insights are off by default."
  }
  assert {
    condition     = length(aws_appautoscaling_target.this) == 0 && length(aws_appautoscaling_policy.this) == 0
    error_message = "No Auto Scaling by default."
  }
  assert {
    condition     = aws_rds_cluster.this.vpc_security_group_ids == toset(["sg-0123456789abcdef0"]) && aws_security_group.this.vpc_id == "vpc-0123456789abcdef0" && startswith(aws_security_group.this.name_prefix, "orders-")
    error_message = "The cluster must use only the module's security group, in vpc_id."
  }
  assert {
    condition     = aws_rds_cluster.this.tags == tomap({ Scope = "Test", Purpose = "Orders Database", Environment = "test" }) && aws_security_group.this.tags["Name"] == "orders"
    error_message = "Unexpected tags."
  }
  assert {
    condition     = output.metadata.rds_cluster.id == "orders" && length(output.metadata.rds_cluster_instance) == 1 && output.metadata.security_group.id == "sg-0123456789abcdef0" && output.metadata.aws.region.abbr == "use1"
    error_message = "Unexpected metadata output."
  }
  assert {
    condition     = alltrue([for k in ["appautoscaling_policy", "appautoscaling_target", "cloudwatch_log_group", "iam_role", "iam_role_policy_attachment", "vpc_security_group_egress_rule", "vpc_security_group_ingress_rule"] : output.metadata[k] == null])
    error_message = "Resources that are not created must be null in metadata."
  }
}
