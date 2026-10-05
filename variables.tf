# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "autoscaling" {
  description = <<-EOT
    Aurora Auto Scaling, which adds and removes reader instances (Aurora Replicas) to follow the load. With the default, `null`, the cluster keeps the instances in `instances.count`.

    - `min_capacity` - (Optional) The fewest readers to keep. Defaults to `1`. AWS adds readers at once to reach it.
    - `max_capacity` - (Required) The most readers, up to `15`.
    - `target_cpu_utilization` - (Optional) Add readers when the readers' average CPU use is above this percentage, and remove them when it is well below.
    - `target_connections` - (Optional) Add readers when the readers' average number of database connections is above this number.
    - `scale_in_cooldown` - (Optional) Seconds to wait after removing a reader before removing another. Defaults to `300`.
    - `scale_out_cooldown` - (Optional) Seconds to wait after adding a reader before adding another. Defaults to `300`.

    Set at least one of `target_cpu_utilization` and `target_connections`. The readers that Auto Scaling adds are not managed by Terraform, and removing `autoscaling` does not delete them: `terraform destroy` fails while they exist. See [Things to know](https://github.com/AutomateTheCloud/terraform-aws-rds_aurora#things-to-know).
  EOT
  type = object({
    min_capacity           = optional(number, 1)
    max_capacity           = number
    target_cpu_utilization = optional(number)
    target_connections     = optional(number)
    scale_in_cooldown      = optional(number, 300)
    scale_out_cooldown     = optional(number, 300)
  })
  default = null

  validation {
    condition     = var.autoscaling == null || try(var.autoscaling.target_cpu_utilization != null || var.autoscaling.target_connections != null, false)
    error_message = "autoscaling needs target_cpu_utilization, target_connections, or both."
  }

  validation {
    condition     = var.autoscaling == null || try(var.autoscaling.min_capacity >= 0 && var.autoscaling.min_capacity <= var.autoscaling.max_capacity && var.autoscaling.max_capacity >= 1 && var.autoscaling.max_capacity <= 15, false)
    error_message = "autoscaling.max_capacity must be from 1 to 15, and min_capacity from 0 to max_capacity."
  }

  validation {
    # Terraform before 1.12 evaluates both sides of ||, so a null target fails the
    # comparison; try() then means "not set", which is allowed.
    condition     = try(var.autoscaling.target_cpu_utilization > 0 && var.autoscaling.target_cpu_utilization <= 100, true)
    error_message = "autoscaling.target_cpu_utilization must be a percentage above 0 and at most 100."
  }

  validation {
    condition     = try(var.autoscaling.target_connections > 0, true)
    error_message = "autoscaling.target_connections must be above 0."
  }

  validation {
    condition     = var.autoscaling == null || try(var.autoscaling.scale_in_cooldown >= 0 && var.autoscaling.scale_out_cooldown >= 0, false)
    error_message = "autoscaling.scale_in_cooldown and scale_out_cooldown must be 0 or more seconds."
  }
}

variable "backup" {
  description = <<-EOT
    Automated backups of the cluster.

    - `retention_period` - (Optional) Days to keep automated backups, from `1` to `35`. Defaults to `7`.
    - `window` - (Optional) The daily time range, in UTC, when backups are taken, such as `04:00-05:00`. At least 30 minutes, and it must not overlap `maintenance.window`. Without it, AWS picks one.
  EOT
  type = object({
    retention_period = optional(number, 7)
    window           = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.backup.retention_period >= 1 && var.backup.retention_period <= 35 && floor(var.backup.retention_period) == var.backup.retention_period
    error_message = "backup.retention_period must be a whole number of days from 1 to 35."
  }

  validation {
    condition     = var.backup.window == null || can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", coalesce(var.backup.window, "-")))
    error_message = "backup.window must be a UTC time range such as 04:00-05:00."
  }
}

variable "cloudwatch_logs" {
  description = <<-EOT
    Database logs sent to Amazon CloudWatch Logs. With the default, no logs are exported.

    - `exports` - (Optional) The log types to export. For `aurora-postgresql`: `postgresql`, `iam-db-auth-error`, `instance`. For `aurora-mysql`: `audit`, `error`, `general`, `slowquery`, `iam-db-auth-error`, `instance`. The `audit`, `general` and `slowquery` logs are written only when turned on in the cluster's parameter group.
    - `retention_in_days` - (Optional) Days to keep the logs. Defaults to `7`. One of `1`, `3`, `5`, `7`, `14`, `30`, `60`, `90`, `120`, `150`, `180`, `365`, `400`, `545`, `731`, `1096`, `1827`, `2192`, `2557`, `2922`, `3288` or `3653`, or `0` to keep them forever.
    - `kms_key_id` - (Optional) ARN of a KMS key to encrypt the logs with. Its key policy must allow the CloudWatch Logs service in the cluster's Region. Without it, CloudWatch Logs encrypts them with a key it owns.

    The module creates a log group for each type, `/aws/rds/cluster/<name>/<type>`, before the cluster, so that the retention and key apply from the first log line.
  EOT
  type = object({
    exports           = optional(set(string), [])
    retention_in_days = optional(number, 7)
    kms_key_id        = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for t in var.cloudwatch_logs.exports :
      contains(var.engine == "aurora-mysql" ? ["audit", "error", "general", "slowquery", "iam-db-auth-error", "instance"] : ["postgresql", "iam-db-auth-error", "instance"], t)
    ])
    error_message = "cloudwatch_logs.exports: aurora-postgresql exports postgresql, iam-db-auth-error and instance; aurora-mysql exports audit, error, general, slowquery, iam-db-auth-error and instance."
  }

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs.retention_in_days)
    error_message = "cloudwatch_logs.retention_in_days must be 0 (forever) or one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }

  validation {
    condition     = var.cloudwatch_logs.kms_key_id == null || startswith(coalesce(var.cloudwatch_logs.kms_key_id, "-"), "arn:")
    error_message = "cloudwatch_logs.kms_key_id must be the ARN of a KMS key."
  }
}

variable "database_name" {
  description = <<-EOT
    The name of a database to create in the cluster, such as `app`. Without it, Aurora PostgreSQL creates only the `postgres` database and Aurora MySQL none. Letters, digits and underscores, starting with a letter: up to 63 characters for PostgreSQL, 64 for MySQL.

    Used only when the cluster is created: changing it later does nothing. It is not set on a restore from a snapshot or a global database secondary, which take their databases from the source.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.database_name == null || can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", coalesce(var.database_name, "-")))
    error_message = "database_name must start with a letter and have only letters, digits and underscores, up to 63 characters."
  }
}

variable "db_cluster_parameter_group_name" {
  description = <<-EOT
    The name of a DB cluster parameter group to use, for settings such as logging and Transport Layer Security (TLS). Its family must match the engine and major version, such as `aurora-postgresql17`. Without it, the cluster uses the engine's default group, which cannot be changed.
  EOT
  type        = string
  default     = null
}

variable "db_parameter_group_name" {
  description = <<-EOT
    The name of a DB parameter group for the instances. Its family must match the engine and major version. Without it, the instances use the engine's default group.
  EOT
  type        = string
  default     = null
}

variable "db_subnet_group_name" {
  description = <<-EOT
    The name of the DB subnet group the cluster's instances are placed in. Its subnets must be in `vpc_id` and cover at least two Availability Zones. Use private subnets: with `instances.publicly_accessible = false`, the default, the instances get no public address.

    Changing it replaces the cluster and deletes its data. With `deletion_protection` on, RDS refuses to delete the cluster, but only after Terraform has deleted its instances.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.db_subnet_group_name) != ""
    error_message = "db_subnet_group_name must not be empty."
  }
}

variable "deletion_protection" {
  description = <<-EOT
    Refuse to delete the cluster. On by default: to destroy the cluster, set it to `false` and apply first.

    It protects the cluster, which holds the data, but not its instances. `terraform destroy`, or a change that replaces the cluster, still deletes every instance before RDS refuses to delete the cluster: the data is kept, but nothing can connect until an apply creates the instances again.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-rds_aurora#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "engine" {
  description = <<-EOT
    The database engine: `aurora-postgresql` or `aurora-mysql`. Changing it replaces the cluster.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = contains(["aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "engine must be \"aurora-postgresql\" or \"aurora-mysql\"."
  }
}

variable "engine_version" {
  description = <<-EOT
    The engine version, such as `17.9` for Aurora PostgreSQL or `8.0.mysql_aurora.3.10.3` for Aurora MySQL. Without it, AWS uses the engine's current default version. `aws rds describe-db-engine-versions --engine <engine> --query "DBEngineVersions[].EngineVersion"` lists the versions.

    Raising it upgrades the cluster and its instances in place, during the maintenance window unless `maintenance.apply_immediately` is `true`. A major version upgrade also needs `maintenance.allow_major_version_upgrade`. When AWS upgrades the minor version on its own (`maintenance.auto_minor_version_upgrade`), Terraform does not try to change it back.
  EOT
  type        = string
  default     = null
}

variable "global_cluster" {
  description = <<-EOT
    Make the cluster a member of an Aurora global database, created separately (for example with `aws_rds_global_cluster`). With the default, `null`, the cluster is a standalone cluster.

    - `identifier` - (Required) The global cluster's identifier.
    - `secondary` - (Optional) `true` for a read-only secondary cluster in another Region, which copies the primary's data. Defaults to `false`, the primary. A secondary takes no `database_name`, `master_username`, `master_password` or `snapshot_identifier`, and needs `kms_key_id` from its own Region.
    - `enable_write_forwarding` - (Optional) Let a secondary cluster forward write statements to the primary. Defaults to `false`.

    Used only when the cluster is created: joining or leaving a global database later is done outside this module. Global databases do not take the burstable `db.t` classes; use a memory-optimized class such as `db.r6g.large`.
  EOT
  type = object({
    identifier              = string
    secondary               = optional(bool, false)
    enable_write_forwarding = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.global_cluster == null || try(!var.global_cluster.enable_write_forwarding || var.global_cluster.secondary, false)
    error_message = "global_cluster.enable_write_forwarding applies only to a secondary cluster (global_cluster.secondary = true)."
  }

  validation {
    condition     = try(var.global_cluster.secondary, false) == false || (var.database_name == null && var.master_username == null && var.master_password == null && var.snapshot_identifier == null)
    error_message = "A global database secondary (global_cluster.secondary = true) takes its databases and master user from the primary: leave database_name, master_username, master_password and snapshot_identifier unset."
  }

  validation {
    condition     = try(var.global_cluster.secondary, false) == false || var.kms_key_id != null
    error_message = "A global database secondary (global_cluster.secondary = true) needs kms_key_id: a KMS key in the secondary's own Region."
  }
}

variable "iam_database_authentication_enabled" {
  description = <<-EOT
    Let database users sign in with AWS Identity and Access Management (IAM) credentials instead of a password. Each database user must still be granted the `rds_iam` role (PostgreSQL) or created with the `AWSAuthenticationPlugin` (MySQL), and the IAM principal needs `rds-db:connect`. Defaults to `false`.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "instances" {
  description = <<-EOT
    The cluster's DB instances. The one RDS creates first is the writer; the others are readers that take over if the writer fails. Each is named `<name>-<number>`.

    - `instance_class` - (Required) The instance class of every instance, such as `db.t4g.medium` or `db.r6g.large`. Not every class supports every engine version or Region: `aws rds describe-orderable-db-instance-options --engine <engine> --engine-version <version>` lists them.
    - `count` - (Optional) The number of instances, from `1` to `16`. Defaults to `1`, a writer with no standby. Use at least `2` for a cluster that must stay available when an instance or Availability Zone fails.
    - `publicly_accessible` - (Optional) Give the instances public IP addresses. Defaults to `false`. Even when `true`, only the sources in `security_group_ingress` can connect, and only from subnets with a route to an internet gateway.
    - `ca_cert_identifier` - (Optional) The certificate authority for the instances' TLS certificates, such as `rds-ca-rsa2048-g1`. Without it, AWS uses the Region's default. `aws rds describe-certificates` lists them.
    - `monitoring_interval` - (Optional) Seconds between Enhanced Monitoring samples: `0` (off, the default), `1`, `5`, `10`, `15`, `30` or `60`. When on, the module creates the IAM role that Enhanced Monitoring uses.
    - `performance_insights_enabled` - (Optional) Turn on Performance Insights. Defaults to `false`. Not every instance class supports it: Aurora MySQL on `db.t3.medium` does not, for example.
    - `performance_insights_retention_period` - (Optional) Days to keep Performance Insights data: `7` (the default, free of charge), `731`, or a multiple of `31` in between.

    Changing the class, or the monitoring and Performance Insights settings, updates the instances in place, one by one, during the maintenance window unless `maintenance.apply_immediately` is `true`.
  EOT
  type = object({
    instance_class                        = string
    count                                 = optional(number, 1)
    publicly_accessible                   = optional(bool, false)
    ca_cert_identifier                    = optional(string)
    monitoring_interval                   = optional(number, 0)
    performance_insights_enabled          = optional(bool, false)
    performance_insights_retention_period = optional(number, 7)
  })
  nullable = false

  validation {
    condition     = startswith(var.instances.instance_class, "db.")
    error_message = "instances.instance_class must be a DB instance class, such as db.t4g.medium."
  }

  validation {
    condition     = var.instances.count >= 1 && var.instances.count <= 16 && floor(var.instances.count) == var.instances.count
    error_message = "instances.count must be a whole number from 1 to 16."
  }

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.instances.monitoring_interval)
    error_message = "instances.monitoring_interval must be 0, 1, 5, 10, 15, 30 or 60."
  }

  validation {
    condition     = var.instances.performance_insights_retention_period == 7 || var.instances.performance_insights_retention_period == 731 || (var.instances.performance_insights_retention_period % 31 == 0 && var.instances.performance_insights_retention_period >= 31 && var.instances.performance_insights_retention_period <= 713)
    error_message = "instances.performance_insights_retention_period must be 7, 731, or a multiple of 31 from 31 to 713."
  }
}

variable "kms_key_id" {
  description = <<-EOT
    ARN of the AWS Key Management Service (KMS) key that encrypts the cluster's storage, its snapshots and Performance Insights data. The cluster is always encrypted; without a key, RDS uses the AWS managed key `aws/rds`.

    Changing the key, including setting one later, replaces the cluster and deletes its data, because RDS cannot change the key of an existing cluster. With `deletion_protection` on, RDS refuses to delete the cluster, but only after Terraform has deleted its instances.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_id == null || startswith(coalesce(var.kms_key_id, "-"), "arn:")
    error_message = "kms_key_id must be the ARN of a KMS key, such as arn:aws:kms:us-east-1:123456789012:key/<key id>."
  }
}

variable "maintenance" {
  description = <<-EOT
    When and how AWS changes the cluster.

    - `window` - (Optional) The weekly time range, in UTC, for maintenance and for changes that are not applied immediately, such as `sun:05:00-sun:06:00`. At least 30 minutes. Without it, AWS picks one.
    - `apply_immediately` - (Optional) Apply changes to the cluster and instances at once instead of in the next maintenance window. Some changes restart the instances. Defaults to `false`.
    - `auto_minor_version_upgrade` - (Optional) Let AWS upgrade the instances to new minor versions in the maintenance window. Defaults to `true`.
    - `allow_major_version_upgrade` - (Optional) Allow a change of `engine_version` to a new major version. Defaults to `false`.
  EOT
  type = object({
    window                      = optional(string)
    apply_immediately           = optional(bool, false)
    auto_minor_version_upgrade  = optional(bool, true)
    allow_major_version_upgrade = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.maintenance.window == null || can(regex("^(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]$", coalesce(var.maintenance.window, "-")))
    error_message = "maintenance.window must be a weekly UTC time range such as sun:05:00-sun:06:00 (lowercase day names)."
  }
}

variable "master_password" {
  description = <<-EOT
    The master user's password. Without it, the default, RDS generates the password and keeps it in AWS Secrets Manager, where it can be rotated, and it is never stored in Terraform state; `metadata.rds_cluster.master_user_secret` gives the secret's ARN.

    A password given here is stored in Terraform state in plain text. Use it only when the password must come from somewhere else. Printable ASCII characters without `/`, `"`, `@` or spaces: 8 to 99 for Aurora PostgreSQL, 8 to 41 for Aurora MySQL. Changing it, or setting or removing it later, updates the cluster in place.
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.master_password == null || can(regex(var.engine == "aurora-mysql" ? "^[!#-.0-?A-~]{8,41}$" : "^[!#-.0-?A-~]{8,99}$", coalesce(var.master_password, "-")))
    error_message = "master_password must be printable ASCII characters without /, \", @ or spaces: 8 to 99 for aurora-postgresql, 8 to 41 for aurora-mysql."
  }
}

variable "master_user_secret_kms_key_id" {
  description = <<-EOT
    ARN of a KMS key to encrypt the Secrets Manager secret that holds the master password. Without it, Secrets Manager uses the AWS managed key `aws/secretsmanager`. Not used with `master_password`.

    Set it when the secret is created: AWS refuses to change the key of an existing secret. A secret created later, when you stop using `master_password`, is encrypted with `aws/secretsmanager` even when this is set.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.master_user_secret_kms_key_id == null || startswith(coalesce(var.master_user_secret_kms_key_id, "-"), "arn:")
    error_message = "master_user_secret_kms_key_id must be the ARN of a KMS key."
  }

  validation {
    condition     = var.master_user_secret_kms_key_id == null || var.master_password == null
    error_message = "master_user_secret_kms_key_id applies only to a password kept in Secrets Manager; leave it unset with master_password."
  }
}

variable "master_username" {
  description = <<-EOT
    The master user's name. Defaults to `postgres` for Aurora PostgreSQL and `admin` for Aurora MySQL. Letters, digits and underscores, starting with a letter: up to 32 characters for MySQL, 63 for PostgreSQL. Each engine also refuses some names when the cluster is created: Aurora PostgreSQL refuses `owner`, for example, and both refuse `rdsadmin`.

    Used only when the cluster is created: changing it later does nothing. It is not set on a restore from a snapshot or a global database secondary, which keep the source's master user.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.master_username == null || can(regex(var.engine == "aurora-mysql" ? "^[A-Za-z][A-Za-z0-9_]{0,31}$" : "^[A-Za-z][A-Za-z0-9_]{0,62}$", coalesce(var.master_username, "-")))
    error_message = "master_username must start with a letter and have only letters, digits and underscores: up to 32 characters for aurora-mysql, 63 for aurora-postgresql."
  }
}

variable "name" {
  description = <<-EOT
    The cluster identifier, such as `orders`, unique among your clusters in the Region. The instances are named `<name>-1`, `<name>-2` and so on. 1 to 60 lowercase letters, digits and hyphens, starting with a letter, with no two hyphens in a row and no hyphen at the end.

    Changing it replaces the cluster and deletes its data. With `deletion_protection` on, RDS refuses to delete the cluster, but only after Terraform has deleted its instances.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9]|-[a-z0-9])*$", var.name)) && length(var.name) <= 60
    error_message = "name must be 1 to 60 lowercase letters, digits and hyphens, starting with a letter, with no two hyphens in a row and no hyphen at the end."
  }
}

variable "port" {
  description = <<-EOT
    The port the database listens on, from `1150` to `65535`. Defaults to `5432` for Aurora PostgreSQL and `3306` for Aurora MySQL. The security group rules in `security_group_ingress` use it.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.port == null || try(var.port >= 1150 && var.port <= 65535 && floor(var.port) == var.port, false)
    error_message = "port must be a whole number from 1150 to 65535."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the cluster and everything else in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.
  EOT
  type        = string
  default     = null
}

variable "security_group_egress" {
  description = <<-EOT
    Where the cluster may connect to. The cluster needs no outbound rules to answer clients, so with the default, `{}`, it can open no connections. Add an entry for a feature that makes the database connect out, such as loading data from Amazon S3 (HTTPS, port `443`, to the S3 prefix list) or invoking AWS Lambda functions. The keys are names you choose; they only identify each rule.

    Each entry takes:

    - `port` - (Required) The TCP port to allow.

    and exactly one of:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
    - `security_group_id` - A security group whose members the cluster may connect to.
    - `prefix_list_id` - A managed prefix list, such as the one for S3 in the Region (`data.aws_ec2_managed_prefix_list` with name `com.amazonaws.<region>.s3`).

    and optionally:

    - `description` - (Optional) What the destination is. Defaults to the key.
  EOT
  type = map(object({
    port              = number
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for s in values(var.security_group_egress) :
      length([for v in [s.cidr_ipv4, s.cidr_ipv6, s.security_group_id, s.prefix_list_id] : v if v != null]) == 1
    ])
    error_message = "Each security_group_egress entry needs exactly one of cidr_ipv4, cidr_ipv6, security_group_id or prefix_list_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.security_group_egress) :
      (s.cidr_ipv4 == null || can(cidrnetmask(s.cidr_ipv4))) && (s.cidr_ipv6 == null || (can(cidrhost(s.cidr_ipv6, 0)) && strcontains(coalesce(s.cidr_ipv6, "-"), ":")))
    ])
    error_message = "security_group_egress: cidr_ipv4 must be an IPv4 range such as 10.0.0.0/16, and cidr_ipv6 an IPv6 range such as 2001:db8::/56."
  }

  validation {
    condition     = alltrue([for s in values(var.security_group_egress) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "security_group_egress: port must be a whole number from 1 to 65535."
  }
}

variable "security_group_ids" {
  description = <<-EOT
    IDs of more security groups to attach to the cluster, besides the one the module creates, such as a group shared by every database.
  EOT
  type        = list(string)
  default     = []
  nullable    = false
}

variable "security_group_ingress" {
  description = <<-EOT
    Who can connect to the database. The module creates a security group for the cluster that allows the database port (`port`) over TCP from each source listed here, and from nothing else. With the default, `{}`, no client can connect. The keys are names you choose; they only identify each rule, so a security group created in the same configuration can be used.

    Each source takes exactly one of:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
    - `security_group_id` - A security group whose members may connect, such as the group of your application servers.
    - `prefix_list_id` - A managed prefix list of ranges.

    and optionally:

    - `description` - (Optional) What the source is. Defaults to the key.
  EOT
  type = map(object({
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      length([for v in [s.cidr_ipv4, s.cidr_ipv6, s.security_group_id, s.prefix_list_id] : v if v != null]) == 1
    ])
    error_message = "Each security_group_ingress entry needs exactly one of cidr_ipv4, cidr_ipv6, security_group_id or prefix_list_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      (s.cidr_ipv4 == null || can(cidrnetmask(s.cidr_ipv4))) && (s.cidr_ipv6 == null || (can(cidrhost(s.cidr_ipv6, 0)) && strcontains(coalesce(s.cidr_ipv6, "-"), ":")))
    ])
    error_message = "security_group_ingress: cidr_ipv4 must be an IPv4 range such as 10.0.0.0/16, and cidr_ipv6 an IPv6 range such as 2001:db8::/56."
  }
}

variable "skip_final_snapshot" {
  description = <<-EOT
    Delete the cluster without taking a final snapshot. Defaults to `false`: deleting the cluster first takes a snapshot named `<name>-final-<8 hex digits>`, which is kept until you delete it.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "snapshot_identifier" {
  description = <<-EOT
    The identifier or ARN of a DB cluster snapshot to create the cluster from, such as a final snapshot of an earlier cluster. The engine must match. The master user and databases come from the snapshot, but the password is set as described in `master_password`.

    Used only when the cluster is created: changing it later does nothing.
  EOT
  type        = string
  default     = null
}

variable "storage_type" {
  description = <<-EOT
    The cluster's storage configuration: `aurora` (Aurora Standard, billed for each I/O request) or `aurora-iopt1` (Aurora I/O-Optimized, no I/O charges and a higher price for storage and instances). Without it, AWS uses Aurora Standard. It can be changed in place, to I/O-Optimized once every 30 days.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.storage_type == null || contains(["aurora", "aurora-iopt1"], coalesce(var.storage_type, "-"))
    error_message = "storage_type must be \"aurora\" or \"aurora-iopt1\"."
  }
}

variable "timeouts" {
  description = <<-EOT
    How long Terraform waits for the cluster to be created, updated or deleted, such as `120m`. Each defaults to `120m`.
  EOT
  type = object({
    create = optional(string, "120m")
    update = optional(string, "120m")
    delete = optional(string, "120m")
  })
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for t in [var.timeouts.create, var.timeouts.update, var.timeouts.delete] : can(regex("^[0-9]+(s|m|h)$", t))])
    error_message = "timeouts values must be durations such as 90m or 2h."
  }
}

variable "vpc_id" {
  description = <<-EOT
    The ID of the VPC the cluster is in, such as `vpc-0123456789abcdef0`: the VPC of `db_subnet_group_name`. The module creates the cluster's security group in it.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "vpc_id must be a VPC ID, such as vpc-0123456789abcdef0."
  }
}
