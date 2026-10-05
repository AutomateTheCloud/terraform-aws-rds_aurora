# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Each validation, with an input it must refuse.
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

run "autoscaling_needs_a_target" {
  command = plan
  variables {
    autoscaling = { max_capacity = 2 }
  }
  expect_failures = [var.autoscaling]
}

run "autoscaling_max_above_15" {
  command = plan
  variables {
    autoscaling = { max_capacity = 16, target_cpu_utilization = 70 }
  }
  expect_failures = [var.autoscaling]
}

run "autoscaling_min_above_max" {
  command = plan
  variables {
    autoscaling = { min_capacity = 3, max_capacity = 2, target_cpu_utilization = 70 }
  }
  expect_failures = [var.autoscaling]
}

run "autoscaling_cpu_above_100" {
  command = plan
  variables {
    autoscaling = { max_capacity = 2, target_cpu_utilization = 101 }
  }
  expect_failures = [var.autoscaling]
}

run "autoscaling_connections_zero" {
  command = plan
  variables {
    autoscaling = { max_capacity = 2, target_connections = 0 }
  }
  expect_failures = [var.autoscaling]
}

run "autoscaling_negative_cooldown" {
  command = plan
  variables {
    autoscaling = { max_capacity = 2, target_connections = 10, scale_in_cooldown = -1 }
  }
  expect_failures = [var.autoscaling]
}

run "backup_retention_zero" {
  command = plan
  variables {
    backup = { retention_period = 0 }
  }
  expect_failures = [var.backup]
}

run "backup_retention_36" {
  command = plan
  variables {
    backup = { retention_period = 36 }
  }
  expect_failures = [var.backup]
}

run "backup_window_format" {
  command = plan
  variables {
    backup = { window = "4:00-5:00" }
  }
  expect_failures = [var.backup]
}

run "logs_type_of_other_engine" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["slowquery"] }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "logs_retention_value" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["postgresql"], retention_in_days = 10 }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "logs_kms_not_arn" {
  command = plan
  variables {
    cloudwatch_logs = { kms_key_id = "alias/logs" }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "database_name_starts_with_digit" {
  command = plan
  variables {
    database_name = "1orders"
  }
  expect_failures = [var.database_name]
}

run "database_name_hyphen" {
  command = plan
  variables {
    database_name = "order-db"
  }
  expect_failures = [var.database_name]
}

run "subnet_group_empty" {
  command = plan
  variables {
    db_subnet_group_name = " "
  }
  expect_failures = [var.db_subnet_group_name]
}

run "engine_unknown" {
  command = plan
  variables {
    engine = "postgres"
  }
  expect_failures = [var.engine]
}

run "write_forwarding_on_primary" {
  command = plan
  variables {
    global_cluster = { identifier = "g", enable_write_forwarding = true }
  }
  expect_failures = [var.global_cluster]
}

run "secondary_with_database_name" {
  command = plan
  variables {
    global_cluster = { identifier = "g", secondary = true }
    kms_key_id     = "arn:aws:kms:us-west-2:111111111111:key/k"
    database_name  = "orders"
  }
  expect_failures = [var.global_cluster]
}

run "secondary_with_password" {
  command = plan
  variables {
    global_cluster  = { identifier = "g", secondary = true }
    kms_key_id      = "arn:aws:kms:us-west-2:111111111111:key/k"
    master_password = "correct-horse-battery"
  }
  expect_failures = [var.global_cluster]
}

run "secondary_without_kms_key" {
  command = plan
  variables {
    global_cluster = { identifier = "g", secondary = true }
  }
  expect_failures = [var.global_cluster]
}

run "instance_class_format" {
  command = plan
  variables {
    instances = { instance_class = "t4g.medium" }
  }
  expect_failures = [var.instances]
}

run "instance_count_zero" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", count = 0 }
  }
  expect_failures = [var.instances]
}

run "instance_count_17" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", count = 17 }
  }
  expect_failures = [var.instances]
}

run "monitoring_interval_value" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", monitoring_interval = 20 }
  }
  expect_failures = [var.instances]
}

run "pi_retention_value" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", performance_insights_enabled = true, performance_insights_retention_period = 30 }
  }
  expect_failures = [var.instances]
}

run "kms_key_not_arn" {
  command = plan
  variables {
    kms_key_id = "alias/aws/rds"
  }
  expect_failures = [var.kms_key_id]
}

run "maintenance_window_format" {
  command = plan
  variables {
    maintenance = { window = "Sun:05:00-Sun:06:00" }
  }
  expect_failures = [var.maintenance]
}

run "password_too_short" {
  command = plan
  variables {
    master_password = "short"
  }
  expect_failures = [var.master_password]
}

run "password_with_at_sign" {
  command = plan
  variables {
    master_password = "correct@horse-battery"
  }
  expect_failures = [var.master_password]
}

run "password_too_long_for_mysql" {
  command = plan
  variables {
    engine          = "aurora-mysql"
    master_password = "a23456789012345678901234567890123456789012"
  }
  expect_failures = [var.master_password]
}

run "password_too_long_for_postgresql" {
  command = plan
  variables {
    master_password = "a234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"
  }
  expect_failures = [var.master_password]
}

run "password_with_space" {
  command = plan
  variables {
    master_password = "correct horse battery"
  }
  expect_failures = [var.master_password]
}

run "secret_key_not_arn" {
  command = plan
  variables {
    master_user_secret_kms_key_id = "alias/secrets"
  }
  expect_failures = [var.master_user_secret_kms_key_id]
}

run "secret_key_with_own_password" {
  command = plan
  variables {
    master_user_secret_kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/k"
    master_password               = "correct-horse-battery"
  }
  expect_failures = [var.master_user_secret_kms_key_id]
}

run "username_hyphen" {
  command = plan
  variables {
    master_username = "db-owner"
  }
  expect_failures = [var.master_username]
}

run "username_too_long_for_mysql" {
  command = plan
  variables {
    engine          = "aurora-mysql"
    master_username = "a23456789012345678901234567890123"
  }
  expect_failures = [var.master_username]
}

run "name_uppercase" {
  command = plan
  variables {
    name = "Orders"
  }
  expect_failures = [var.name]
}

run "name_double_hyphen" {
  command = plan
  variables {
    name = "orders--db"
  }
  expect_failures = [var.name]
}

run "name_trailing_hyphen" {
  command = plan
  variables {
    name = "orders-"
  }
  expect_failures = [var.name]
}

run "name_too_long" {
  command = plan
  variables {
    name = "a234567890123456789012345678901234567890123456789012345678901"
  }
  expect_failures = [var.name]
}

run "port_below_1150" {
  command = plan
  variables {
    port = 1149
  }
  expect_failures = [var.port]
}

run "egress_two_destinations" {
  command = plan
  variables {
    security_group_egress = { s3 = { port = 443, cidr_ipv4 = "10.0.0.0/8", prefix_list_id = "pl-63a5400a" } }
  }
  expect_failures = [var.security_group_egress]
}

run "egress_bad_cidr" {
  command = plan
  variables {
    security_group_egress = { x = { port = 443, cidr_ipv6 = "10.0.0.0/8" } }
  }
  expect_failures = [var.security_group_egress]
}

run "egress_port_zero" {
  command = plan
  variables {
    security_group_egress = { x = { port = 0, cidr_ipv4 = "10.0.0.0/8" } }
  }
  expect_failures = [var.security_group_egress]
}

run "ingress_no_source" {
  command = plan
  variables {
    security_group_ingress = { x = { description = "nothing" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "ingress_bad_cidr" {
  command = plan
  variables {
    security_group_ingress = { x = { cidr_ipv4 = "10.0.0.0" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "storage_type_value" {
  command = plan
  variables {
    storage_type = "gp3"
  }
  expect_failures = [var.storage_type]
}

run "timeout_format" {
  command = plan
  variables {
    timeouts = { create = "3 hours" }
  }
  expect_failures = [var.timeouts]
}

run "vpc_id_format" {
  command = plan
  variables {
    vpc_id = "0123456789abcdef0"
  }
  expect_failures = [var.vpc_id]
}

# Accepted edge values.
run "edge_values_accepted" {
  command = plan
  variables {
    name            = "a23456789012345678901234567890123456789012345678901234567890"
    port            = 65535
    master_username = "a2345678901234567890123456789012345678901234567890123456789012b"
    master_password = "Abc!#$%&'()*+,-.:;<=>?[]^_`{|}~1"
    instances       = { instance_class = "db.t4g.medium", count = 16, monitoring_interval = 1, performance_insights_enabled = true, performance_insights_retention_period = 713 }
    backup          = { retention_period = 35 }
    cloudwatch_logs = { exports = ["postgresql", "iam-db-auth-error", "instance"], retention_in_days = 0 }
    autoscaling     = { min_capacity = 0, max_capacity = 15, target_connections = 1 }
  }
}
