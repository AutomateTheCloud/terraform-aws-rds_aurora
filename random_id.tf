# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A suffix for the final snapshot's name, so that deleting a cluster that was created
# again under the same name does not fail on the earlier cluster's final snapshot.
resource "random_id" "final_snapshot" {
  keepers = {
    name = var.name
  }
  byte_length = 4
}
