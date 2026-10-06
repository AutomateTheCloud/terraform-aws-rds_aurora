# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A suffix for the final snapshot's name, so that deleting a cluster that was created
# again under the same name does not fail on the earlier cluster's final snapshot. The
# keepers are every input that replaces the cluster (its ForceNew arguments in provider
# 6.67.0, less database_name, master_username and snapshot_identifier, which
# ignore_changes keeps from replacing it), so a replacement gets a new suffix: otherwise
# the replaced cluster's final snapshot takes the name, and deleting the new cluster
# fails because the snapshot exists.
resource "random_id" "final_snapshot" {
  keepers = {
    name                 = var.name
    engine               = var.engine
    kms_key_id           = var.kms_key_id
    db_subnet_group_name = var.db_subnet_group_name
  }
  byte_length = 4
}
