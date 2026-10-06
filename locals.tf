# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # A global database secondary takes its databases and master user from the primary.
  secondary = try(var.global_cluster.secondary, false)

  port = coalesce(var.port, var.engine == "aurora-postgresql" ? 5432 : 3306)

  master_username = coalesce(var.master_username, var.engine == "aurora-postgresql" ? "postgres" : "admin")

  # Without a password of the caller's own, RDS keeps one in Secrets Manager. Decided from
  # whether the input is null, so a password created in the same run still plans. Whether
  # a password was given is not secret; without nonsensitive(), the sensitive mark of
  # master_password would make the whole metadata output sensitive.
  manage_master_user_password = !local.secondary && nonsensitive(var.master_password == null)

  # The scaling policies, keyed by a fixed name, from the inputs alone.
  autoscaling_policies = var.autoscaling == null ? {} : {
    for k, v in {
      cpu = {
        metric = "RDSReaderAverageCPUUtilization"
        target = var.autoscaling.target_cpu_utilization
      }
      connections = {
        metric = "RDSReaderAverageDatabaseConnections"
        target = var.autoscaling.target_connections
      }
    } : k => v if v.target != null
  }
}
