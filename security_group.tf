# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The cluster's security group. It allows the database port from the sources in
# security_group_ingress and nothing else, and has outbound rules only from
# security_group_egress: the cluster answers clients without any.
resource "aws_security_group" "this" {
  region                 = var.region
  name_prefix            = "${var.name}-"
  description            = "Aurora cluster ${var.name}"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(local.tags, { Name = var.name })

  # A new VPC or name replaces the group. Creating the new group first lets the cluster
  # move to it before the old one, which the cluster still uses, is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
