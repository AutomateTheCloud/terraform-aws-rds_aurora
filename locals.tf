locals {
  database_master_password = try(var.credentials.master.password, null) != null ? var.credentials.master.password : random_password.master_password.result

  kms_key_id = try(var.encryption.enabled, true) ? try(var.encryption.kms_key_id, "alias/aws/rds") : null
  port       = try(var.port, null) != null ? var.port : local.port_default_lookup["${var.db_type}"]

  port_default_lookup = {
    mysql      = "3306"
    postgresql = "5432"
  }

  ignore_admin_credentials = var.replication_source_identifier != null || try(var.global_cluster.secondary, false) ? true : false
}
