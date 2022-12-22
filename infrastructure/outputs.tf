output "redis_address" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_address_ssmpath" {
  value = local.redis_address_ssmpath
}