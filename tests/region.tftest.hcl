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

run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables {
    region                 = "us-west-2"
    instances              = { instance_class = "db.t4g.medium", count = 2, monitoring_interval = 60 }
    cloudwatch_logs        = { exports = ["postgresql"] }
    security_group_ingress = { vpc = { cidr_ipv4 = "10.0.0.0/16" } }
    security_group_egress  = { s3 = { port = 443, prefix_list_id = "pl-68a54001" } }
    autoscaling            = { max_capacity = 3, target_cpu_utilization = 70 }
  }
  assert {
    condition = alltrue([
      aws_rds_cluster.this.region == "us-west-2",
      aws_rds_cluster_instance.this[0].region == "us-west-2",
      aws_rds_cluster_instance.this[1].region == "us-west-2",
      aws_security_group.this.region == "us-west-2",
      aws_vpc_security_group_ingress_rule.this["vpc"].region == "us-west-2",
      aws_vpc_security_group_egress_rule.this["s3"].region == "us-west-2",
      aws_cloudwatch_log_group.this["postgresql"].region == "us-west-2",
      aws_appautoscaling_target.this[0].region == "us-west-2",
      aws_appautoscaling_policy.this["cpu"].region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
    ])
    error_message = "region was not passed through to every resource."
  }
  assert {
    condition     = strcontains(aws_iam_role.monitoring[0].description, "us-west-2")
    error_message = "The global monitoring role should name the Region it is for."
  }
}

# Any Region plans, including ones added after this module was written.
run "region_not_in_old_tables" {
  command = plan
  variables { region = "ap-southeast-7" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse7"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_mexico" {
  command = plan
  variables { region = "mx-central-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "mxc1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}

# Other partitions: the managed policy ARN follows the partition.
run "partition_in_policy_arn" {
  command = plan
  variables {
    region    = "cn-north-1"
    instances = { instance_class = "db.t4g.medium", monitoring_interval = 60 }
  }
  override_data {
    target = data.aws_partition.this
    values = { partition = "aws-cn" }
  }
  assert {
    condition     = aws_iam_role_policy_attachment.monitoring[0].policy_arn == "arn:aws-cn:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
    error_message = "The policy ARN must use the partition."
  }
}
