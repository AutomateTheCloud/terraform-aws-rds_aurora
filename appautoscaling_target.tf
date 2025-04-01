resource "aws_appautoscaling_target" "this" {
  count              = try(var.autoscaling.scale_on_cpu.enabled, false) || try(var.autoscaling.scale_on_connection_count.enabled, false) ? 1 : 0
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  max_capacity       = try(var.autoscaling.capacity.max, 1)
  min_capacity       = try(var.autoscaling.capacity.min, 1)
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"
  provider           = aws.this
}
