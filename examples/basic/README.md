# Basic cluster

An Amazon Aurora PostgreSQL cluster with one `db.t3.medium` instance and an `orders` database, in private subnets you give. Anything in the VPC can connect on port 5432. RDS generates the master password and keeps it in AWS Secrets Manager.

Everything else uses the module's defaults: encryption with the AWS managed key, the engine's current default version, backups kept for 7 days, deletion protection on, and a final snapshot when the cluster is deleted.

## Run it

Choose a VPC and private subnets in at least two Availability Zones:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

Creating the cluster takes about 15 minutes. Read the master password from the secret in the `cluster` output:

```shell
aws secretsmanager get-secret-value --secret-id <secret_arn> --query SecretString --output text
```

and connect from an instance in the VPC with `psql "host=<endpoint> port=5432 dbname=orders user=postgres sslmode=require"`.

Deletion protection is on, so remove the cluster in two steps, with the same `-var` options:

```shell
terraform apply -var 'deletion_protection=false' ...
terraform destroy -var 'deletion_protection=false' ...
```

The destroy keeps a final snapshot, `example-basic-final-<8 hex digits>`, until you delete it.

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
