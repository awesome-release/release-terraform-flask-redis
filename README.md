# Terraform, Flask, and Redis example

This example application illustrates Release-specific Terraform configuration.

## Quick start

1.  Fork this repository.

2.  Add a new Release application using this repository.

3.  Add an [infrastructure runner](https://docs.releasehub.com/reference-documentation/application-settings/application-template/schema-definition#infrastructure) to your Release application template.
    ```yaml
    infrastructure:
    - name: terraform-redis
      type: terraform
      directory: "./infrastructure"
    ```

4.  Map an environment variable for `REDIS_HOST`:
    ```yaml
    mapping:
      REDIS_HOST: ssm:///${RELEASE_ENV_ID}/redis/address
    ```

5.  Deploy the application.

## Detailed tutorial

For a detailed guide on using this application, work through the [Terraform and Flask](https://docs.releasehub.com/guides-and-examples/common-setup-examples/terraform-flask-redis) tutorial from the Release documentation.

## How it works

Terraform configuration can access environment variables that start with `TF_VAR_` by name.

Before running Terraform, Release automatically prepends `TF_VAR_` to all environment variables that start with `RELEASE_`.

This means you can reference all environment variables that start with `RELEASE_` by adding them to a values file, or by declaring variable blocks for them.

Terraform configuration in the `infrastructure` folder of this application uses three environment variables: `RELEASE_APP_NAME`, `RELEASE_ENV_ID`, and `RELEASE_CONTEXT`.

From `infrastructure/variables.tf`:

```hcl
variable "RELEASE_APP_NAME" {
  type        = string
  description = "Name of the Release application"
}

variable "RELEASE_ENV_ID" {
  type        = string
  description = "Unique identifier for the Release environment"
}

variable "RELEASE_CONTEXT" {
  type        = string
  description = "Release context"
}
```

The value of `RELEASE_CONTEXT` is passed to the [`awesome-release/terraform-aws-release-network`](https://github.com/awesome-release/terraform-aws-release-network) example Terraform module.

From `infrastructure/main.tf`:

```hcl
# Import the Release network module
module "release_network" {
  source = "github.com/awesome-release/terraform-aws-release-network"
  # Pass in the Release context from the environment variables
  release_context = var.RELEASE_CONTEXT
}
```

Outputs from `awesome-release/terraform-aws-release-network` are used to create a Redis cluster in your Release cluster's VPC.

From `infrastructure/main.tf`:

```hcl
# Local variables for use with Redis resources
locals {
  redis_address_ssmpath = "/${var.RELEASE_ENV_ID}/redis/address"
}

# Create a subnet group for the Redis cluster
resource "aws_elasticache_subnet_group" "redis" {
  name                 = "redis-${var.RELEASE_ENV_ID}"
  subnet_ids           = module.release_network.private_subnet_ids
}

# Create the Redis cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-${var.RELEASE_ENV_ID}"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  security_group_ids   = [module.release_network.security_group_id]
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
}
```

Terraform sets an AWS SSM parameter to store the new Redis cluster's hostname.

From `infrastructure/main.tf`:

```hcl
# Create an SSM parameter for the Redis address
resource "aws_ssm_parameter" "redis_address" {
  name        = local.redis_address_ssmpath
  description = "Redis address"
  type        = "String"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}
```

The entrypoint for this application's docker image is [`ssm-env`](https://github.com/remind101/ssm-env/), which replaces environment variables that reference SSM parameters with the values from the SSM parameters.

From `app/Dockerfile`:

```dockerfile
RUN wget -O /usr/local/bin/ssm-env https://github.com/remind101/ssm-env/releases/download/v0.0.5/ssm-env && \
      cd /usr/local/bin && \
      echo 'babf40382bcd260f0d8d4575a32d5ec33fb08fefd29f12ffd800fbe738c41021  ssm-env' | sha256sum -c && \
      chmod +x ssm-env

ENTRYPOINT ["/usr/local/bin/ssm-env", "-with-decryption"]
```

No AWS authentication details are added to the running containers in Release, but calls to AWS SSM are authenticated [using AWS metadata](https://docs.releasehub.com/integrations/integrations-overview/aws-integration/grant-access-to-aws-resources-s3-etc.-from-release#using-aws-metadata).

For `ssm-env` to fetch the correct value for `REDIS_HOST`, map `REDIS_HOST` to `ssm:///${RELEASE_ENV_ID}/redis/address` in your Release application's default environment variables.

## External links

- [Get started with Terraform](https://docs.releasehub.com/guides-and-examples/advanced-guides/infrastructure/terraform) – Release documentation about using Terraform
- [Infrastructure as code (IaC)](https://docs.releasehub.com/guides-and-examples/advanced-guides/infrastructure) – Release documentation about IaC