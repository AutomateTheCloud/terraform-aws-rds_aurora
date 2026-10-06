# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One log group per exported log type, keyed by the type, so adding or removing one
# leaves the others and their logs alone.
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.cloudwatch_logs.exports

  region            = var.region
  name              = "/aws/rds/cluster/${var.name}/${each.key}"
  retention_in_days = var.cloudwatch_logs.retention_in_days
  kms_key_id        = var.cloudwatch_logs.kms_key_id

  tags = local.tags
}
