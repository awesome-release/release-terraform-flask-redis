terraform {
  required_version = ">= 0.12.0"
  required_providers {
    aws = ">= 2.0.0"
  }
}

provider "aws" {
  # The AWS region to use.
  # When run by Release, this will be set to the region of your Release cluster.
  region = "us-west-2"

  default_tags {
    # These tags are optional, but recommended to help identify resources
    tags = {
      "releasehub.com/app-name" = var.RELEASE_APP_NAME
      "releasehub.com/env-id"   = var.RELEASE_ENV_ID
      "releasehub.com/context"  = var.RELEASE_CONTEXT
      "terraform"               = "true"
    }
  }
}

# Import the Release AWS network module from GitHub
module "release_network" {
  source = "github.com/awesome-release/terraform-aws-release-network"
  # Pass in the Release context from the environment variables
  release_context = var.RELEASE_CONTEXT
}

/****************
* Redis cluster *
****************/

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

/*****************
* SSM Parameters *
*****************/

# Create an SSM parameter for the Redis address
resource "aws_ssm_parameter" "redis_address" {
  name        = local.redis_address_ssmpath
  description = "Redis address"
  type        = "String"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}