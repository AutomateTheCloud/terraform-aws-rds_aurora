# Complete

Most of the module's options together, for an Aurora PostgreSQL 17.9 cluster that only the application's servers can reach:

- Two `db.t3.medium` instances, a writer and a reader, and Aurora Auto Scaling that adds up to two more readers when the readers' average CPU use is above 70%.
- A KMS key of your own, with automatic rotation, for the storage, snapshots, Performance Insights data and the Secrets Manager secret that holds the master password.
- A cluster parameter group that logs statements running longer than one second, with the `postgresql` and `iam-db-auth-error` logs exported to CloudWatch Logs and kept for 30 days.
- Access on port 5432 only from the members of a security group the example creates for the application, and IAM database authentication.
- One outbound rule, HTTPS to Amazon S3, for loading data from S3. It also needs an IAM role associated with the cluster and a route to S3, which the example does not create.
- Enhanced Monitoring every 60 seconds, Performance Insights, 14 days of backups, and fixed backup and maintenance windows.

## Run it

Choose a VPC and private subnets in at least two Availability Zones:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

Add your application's instances to the security group in the `app_security_group` output. To let one of them sign in with IAM database authentication, create a database user with `CREATE USER app; GRANT rds_iam TO app;`, and give its IAM role `rds-db:connect` on `arn:aws:rds-db:us-east-1:<account>:dbuser:<cluster_resource_id>/app`.

Deletion protection is on, so remove the cluster in two steps, with the same `-var` options:

```shell
terraform apply -var 'deletion_protection=false' ...
terraform destroy -var 'deletion_protection=false' ...
```

The destroy keeps a final snapshot, `example-complete-final-<8 hex digits>`, until you delete it, and the KMS key is deleted after 7 days. If Auto Scaling has added readers, delete them first, as described in the module's [Things to know](https://github.com/AutomateTheCloud/terraform-aws-rds_aurora#auto-scaling).

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

- <a name="requirement_random"></a> [random](#requirement_random) (~> 3.0)

### Required Inputs

The following input variables are required:

#### <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)

Description: IDs of private subnets for the cluster, in at least two Availability Zones

Type: `list(string)`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the cluster in

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_deletion_protection"></a> [deletion_protection](#input_deletion_protection)

Description: Refuse to delete the cluster. Set it to false and apply before terraform destroy.

Type: `bool`

Default: `true`

### Outputs

The following outputs are exported:

#### <a name="output_cluster"></a> [cluster](#output_cluster)

Description: Where to connect, and the Secrets Manager secret that holds the master password
<!-- END_TF_DOCS -->
