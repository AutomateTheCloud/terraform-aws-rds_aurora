resource "aws_appautoscaling_policy" "scale_on_cpu" {
  count              = try(var.autoscaling.scale_on_cpu.enabled, false) ? 1 : 0
  name               = "scale_on_cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
    scale_in_cooldown  = try(var.autoscaling.scale_on_cpu.scale_in_cooldown, 300)
    scale_out_cooldown = try(var.autoscaling.scale_on_cpu.scale_out_cooldown, 300)
    target_value       = try(var.autoscaling.scale_on_cpu.threshold, 80)
  }
  depends_on = [aws_appautoscaling_target.this]
  provider   = aws.this
}

resource "aws_appautoscaling_policy" "scale_on_connection_count" {
  count              = try(var.autoscaling.scale_on_connection_count.enabled, false) ? 1 : 0
  name               = "scale_on_connection_count"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageDatabaseConnections"
    }
    scale_in_cooldown  = try(var.autoscaling.scale_on_connection_count.scale_in_cooldown, 300)
    scale_out_cooldown = try(var.autoscaling.scale_on_connection_count.scale_out_cooldown, 300)
    target_value       = try(var.autoscaling.scale_on_connection_count.threshold, 800)
  }
  depends_on = [aws_appautoscaling_target.this]
  provider   = aws.this
}
