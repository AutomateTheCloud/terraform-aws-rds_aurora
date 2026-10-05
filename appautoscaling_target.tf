# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_appautoscaling_target" "this" {
  count = var.autoscaling == null ? 0 : 1

  region             = var.region
  service_namespace  = "rds"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  min_capacity       = var.autoscaling.min_capacity
  max_capacity       = var.autoscaling.max_capacity

  tags = local.tags

  # Aurora Auto Scaling needs the writer instance to exist.
  depends_on = [aws_rds_cluster_instance.this]
}
