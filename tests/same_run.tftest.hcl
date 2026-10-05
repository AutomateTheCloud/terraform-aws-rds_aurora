# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Inputs created in the same run: the VPC, subnet group, client security group, KMS key
# and password are unknown at plan time. The old module failed to plan with a client
# security group ("Invalid for_each argument") or a KMS key ("Invalid count argument")
# from the same run.
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
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:111111111111:key/same-run" }
  }
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
}

run "same_run_plans" {
  command = plan
  module {
    source = "./tests/fixtures/same_run"
  }
}

run "same_run_plans_with_own_password" {
  command = plan
  module {
    source = "./tests/fixtures/same_run"
  }
  variables {
    own_password = true
  }
}

run "same_run_applies" {
  command = apply
  module {
    source = "./tests/fixtures/same_run"
  }
  assert {
    condition     = length(output.metadata.vpc_security_group_ingress_rule) == 2 && output.metadata.rds_cluster.kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/same-run"
    error_message = "Expected two rules and the same-run key."
  }
}
