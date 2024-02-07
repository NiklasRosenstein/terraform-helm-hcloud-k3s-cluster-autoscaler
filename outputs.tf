
output "hcloud_cluster_config" {
  value = local.hcloud_cluster_config
}

output "node_pools" {
  value = var.node_pools
}

output "node_pool_labels" {
  value = local.node_pool_labels
}

output "node_pool_taints" {
  value = local.node_pool_taints
}
