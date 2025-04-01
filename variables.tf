variable "autoscaling" {
  description = "Autoscaling"
  type        = any
  default     = null
}

variable "backup" {
  description = "Backup"
  type        = any
  default     = null
}

variable "ca_cert_identifier" {
  description = "The identifier of the CA certificate for the DB instances"
  type        = string
  default     = "rds-ca-2019"
}

variable "cloudwatch" {
  description = "Cloudwatch"
  type        = any
  default     = null
}

variable "credentials" {
  description = "Credentials"
  type        = any
  default     = null
}

variable "db_cluster_parameter_group_name" {
  description = "Cluster parameter group to associate with the cluster"
  type        = string
  default     = null
}

variable "db_name" {
  description = "Database Name"
  type        = string
  default     = null
}

variable "db_parameter_group_name" {
  description = "Parameter group to use for instances in the cluster"
  type        = string
  default     = null
}

variable "db_subnet_group_name" {
  description = "Database Subnet Group name"
  type        = string
  default     = ""
}

variable "db_type" {
  description = "Database Type"
  type        = string
  default     = null
}

variable "encryption" {
  description = "Encryption"
  type        = any
  default     = null
}

variable "engine_version" {
  # aws rds describe-db-engine-versions --engine aurora-mysql --query "DBEngineVersions[].EngineVersion"
  # aws rds describe-db-engine-versions --engine aurora-postgresql --query "DBEngineVersions[].EngineVersion"
  description = "Engine Version"
  type        = string
  default     = null
}

variable "global_cluster" {
  description = "Global Cluster"
  type        = any
  default     = null
}

variable "instance" {
  description = "Instance"
  type        = any
  default     = null
}

variable "maintenance" {
  description = "Maintenance"
  type        = any
  default     = null
}

variable "monitoring_interval" {
  description = "Monitoring Interval"
  type        = number
  default     = 0
}

variable "name" {
  description = "Name"
  type        = string
  default     = null
}

variable "performance_insights" {
  description = "Performance Insights"
  type        = any
  default     = null
}

variable "port" {
  description = "Port"
  type        = number
  default     = null
}

variable "replication_source_identifier" {
  description = "Replication Source Identifier"
  type        = string
  default     = null
}

variable "s3_support" {
  description = "S3 Support"
  type        = bool
  default     = false
}

variable "security_groups_additional" {
  description = "Security Groups (Additional)"
  type        = list(any)
  default     = []
}

variable "security_group_rules" {
  description = "Security Group Rules"
  type        = any
  default     = null
}

variable "storage_type" {
  description = "Storage Type"
  type        = string
  default     = ""
}

variable "snapshot_identifier" {
  description = "Database Snapshot ARN to create this database from"
  type        = string
  default     = null
}

variable "timeouts" {
  description = "Timeouts"
  type        = any
  default = {
    create = "180m"
    delete = "120m"
    update = "120m"
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = ""
}
