# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Fixed

- The final snapshot's name now changes whenever the cluster is replaced, not only when it is renamed. A replacement, such as a new `db_subnet_group_name`, kept the name, so the replaced cluster's final snapshot took it, and deleting the new cluster would then fail because a snapshot with that name exists. Upgrading from 1.0.0 gives an existing cluster a new final snapshot name once, as an in-place change.

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An Aurora PostgreSQL or Aurora MySQL cluster with secure defaults: always encrypted, the master password kept in AWS Secrets Manager instead of Terraform state, no network access until you allow a source, no public addresses, deletion protection, and a final snapshot on delete.
- One to 16 DB instances, with promotion tiers for failover, and optional public addresses.
- A security group that allows the database port from IPv4 and IPv6 ranges, security groups and prefix lists, and outbound rules only where you add them.
- Your own KMS key for storage, Performance Insights and the Secrets Manager secret, or your own master password.
- Backups and maintenance windows, engine version upgrades, I/O-Optimized storage, IAM database authentication, and custom parameter groups.
- Exported logs, each in a log group with its own retention and optional KMS key, Enhanced Monitoring with its IAM role, and Performance Insights.
- Aurora Auto Scaling of readers on CPU use or connections.
- Restoring from a snapshot, and joining an Aurora global database as the primary or a secondary.
- `region`, to create the cluster in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for a basic cluster and most options together.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-rds_aurora/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-rds_aurora/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-rds_aurora/releases/tag/v1.0.0
