resource "aws_cloudwatch_log_group" "this" {
  count             = try(length(var.cloudwatch.exports), 0)
  name              = "/aws/rds/cluster/${var.name}/${var.cloudwatch.exports[count.index]}"
  retention_in_days = try(var.cloudwatch.retention, 7)
  tags              = local.tags
  provider          = aws.this
}
