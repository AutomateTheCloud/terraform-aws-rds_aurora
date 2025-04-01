resource "aws_security_group" "this" {
  name                   = "rds-${var.name}"
  description            = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): RDS - ${var.name}"
  vpc_id                 = data.aws_vpc.this.id
  revoke_rules_on_delete = true
  tags = merge(
    local.tags,
    tomap({
      "Name" = "rds-${var.name}"
    })
  )
  provider = aws.this
}
