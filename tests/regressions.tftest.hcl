# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Bugs found in the module before 1.0.0, each with the input that showed it.
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

# security_group_rules defaulted to null, and every plan without it failed with
# "Iteration over null value". Now no rules is the default.
run "no_ingress_rules_plans" {
  command = plan
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "A cluster with no ingress rules must plan."
  }
}

# An IPv6 range was sent as source_security_group_id.
run "ipv6_source_is_a_cidr" {
  command = plan
  variables {
    security_group_ingress = { v6 = { cidr_ipv6 = "2001:db8::/56" } }
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["v6"].cidr_ipv6 == "2001:db8::/56" && aws_vpc_security_group_ingress_rule.this["v6"].referenced_security_group_id == null
    error_message = "An IPv6 range must be a cidr_ipv6 rule."
  }
}

# The Enhanced Monitoring role was named rds_em-<name>: longer than IAM's 64 characters
# for a long name, and the same in every Region.
run "long_name_monitoring_role" {
  command = plan
  variables {
    name      = "a23456789012345678901234567890123456789012345678901234567890"
    instances = { instance_class = "db.t4g.medium", monitoring_interval = 60 }
  }
  assert {
    condition     = length(aws_iam_role.monitoring[0].name_prefix) <= 38 && aws_iam_role.monitoring[0].name_prefix == "a234567890123456789012-rds-monitoring-"
    error_message = "The role must use a name prefix that IAM can complete within 64 characters."
  }
}

# The CA certificate defaulted to rds-ca-2019, which AWS has retired (CertificateNotFound).
run "ca_certificate_left_to_aws" {
  command = plan
  assert {
    # Unset in the configuration, so unknown at plan: AWS picks the certificate.
    condition     = var.instances.ca_cert_identifier == null
    error_message = "Without ca_cert_identifier, AWS's default certificate must be used."
  }
}

# Log groups were a list by position: removing the first log type renamed the others,
# which replaces them and deletes their logs. They are keyed by log type now.
run "log_groups_keyed_by_type" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["iam-db-auth-error"] }
  }
  assert {
    condition     = keys(aws_cloudwatch_log_group.this) == ["iam-db-auth-error"] && aws_cloudwatch_log_group.this["iam-db-auth-error"].name == "/aws/rds/cluster/orders/iam-db-auth-error"
    error_message = "Log groups must be keyed by log type."
  }
}

# A name whose 22nd character is a hyphen gave a role name with two hyphens in a row.
run "monitoring_role_prefix_trimmed" {
  command = plan
  variables {
    name      = "atc-tfmod-test-20160c-b"
    instances = { instance_class = "db.t4g.medium", monitoring_interval = 60 }
  }
  assert {
    condition     = aws_iam_role.monitoring[0].name_prefix == "atc-tfmod-test-20160c-rds-monitoring-"
    error_message = "Unexpected role name prefix."
  }
}

# Sixteen instances gave the last one promotion tier 16; RDS allows 0 to 15.
run "promotion_tier_within_range" {
  command = plan
  variables {
    instances = { instance_class = "db.t4g.medium", count = 16 }
  }
  assert {
    condition     = aws_rds_cluster_instance.this[15].promotion_tier == 15 && aws_rds_cluster_instance.this[0].promotion_tier == 0
    error_message = "Promotion tiers must stay within 0 to 15."
  }
}

# Performance Insights was on by default, and AWS refuses it on some instance classes.
run "performance_insights_opt_in" {
  command = plan
  variables {
    engine    = "aurora-mysql"
    instances = { instance_class = "db.t3.medium" }
  }
  assert {
    condition     = aws_rds_cluster_instance.this[0].performance_insights_enabled == false
    error_message = "Performance Insights must be off unless asked for."
  }
}

# The S3 support switch allowed HTTPS to the whole internet, and every ingress source got
# a matching egress rule. Egress now comes only from security_group_egress.
run "no_egress_from_ingress" {
  command = plan
  variables {
    security_group_ingress = { office = { cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "Ingress sources must not get egress rules."
  }
}

# Apply, then change inputs: engine_version was in ignore_changes, so an upgrade planned
# no change at all.
run "apply_for_changes" {
  command = apply
  variables {
    engine_version = "16.4"
  }
}

run "engine_version_change_is_planned" {
  command = plan
  variables {
    engine_version = "16.6"
  }
  assert {
    condition     = aws_rds_cluster.this.engine_version == "16.6"
    error_message = "An engine version change must reach the cluster."
  }
}

# The instances set engine_version too, which the provider says must change on the
# cluster only.
run "instances_take_version_from_cluster" {
  command = plan
  variables {
    engine_version = "16.4"
  }
  assert {
    condition     = aws_rds_cluster.this.engine_version == "16.4"
    error_message = "Expected the cluster's version."
  }
}

# The final snapshot's suffix changed only with the name, so a change that replaces the
# cluster, such as db_subnet_group_name, kept it: the replaced cluster's final snapshot
# took the name, and deleting the new cluster would fail on it.
run "final_snapshot_suffix_follows_replacing_inputs" {
  command = plan
  variables {
    kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/0000"
  }
  assert {
    condition = alltrue([
      random_id.final_snapshot.keepers["name"] == "orders",
      random_id.final_snapshot.keepers["engine"] == "aurora-postgresql",
      random_id.final_snapshot.keepers["db_subnet_group_name"] == "private",
      random_id.final_snapshot.keepers["kms_key_id"] == "arn:aws:kms:us-east-1:111111111111:key/0000",
    ])
    error_message = "Every input that replaces the cluster must change the final snapshot's suffix."
  }
  # Inputs that ignore_changes keeps from replacing the cluster must not change it.
  assert {
    condition     = length(setintersection(keys(random_id.final_snapshot.keepers), ["database_name", "master_username", "snapshot_identifier"])) == 0
    error_message = "Inputs that do not replace the cluster must not change the final snapshot's suffix."
  }
}
