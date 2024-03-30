
locals {
  # Decode string-formatted labels and taints.
  node_pool_labels = { for pool in var.node_pools : pool.name => { for label in pool.labels : split("=", label)[0] => split("=", label)[1] } }
  node_pool_taints = { for pool in var.node_pools : pool.name => [for taint in pool.taints : {
    "key"    = split("=", taint)[0]
    "value"  = split(":", split("=", taint)[1])[0]
    "effect" = split(":", split("=", taint)[1])[1]
  }] }

  # Define the HCLOUD_CLUSTER_CONFIG payload, see https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/hetzner/README.md
  # for more details on the schema.
  hcloud_cluster_config = {
    "imagesForArch" = {
      "arm64" = var.hcloud_image_arm64,
      "amd64" = var.hcloud_image_amd64,
    },
    "nodeConfigs" = {
      for pool in var.node_pools : pool.name => {
        "cloudInit" = templatefile("${path.module}/files/cloud-init.yaml", {
          private_network_gateway_ip = var.private_network_gateway_ip
          k3s_installer_url          = var.k3s_installer_url
          k3s_token                  = var.k3s_token
          k3s_version                = var.k3s_version
          k3s_url                    = var.k3s_url
          sshd_config                = var.sshd_config
          node_labels                = pool.labels
          node_taints                = pool.taints
        })
        "labels" = local.node_pool_labels[pool.name]
        "taints" = local.node_pool_taints[pool.name]
      }
    }
  }
}

resource "helm_release" "cluster-autoscaler" {
  namespace        = var.namespace
  create_namespace = var.create_namespace
  name             = var.release_name
  chart            = "${path.module}/files/cluster-autoscaler-9.36.0-g9d73b59.tgz"

  values = [yamlencode({
    "fullnameOverride" = var.release_name
    "cloudProvider"    = "hetzner"
    "autoscalingGroups" = [
      for pool in var.node_pools : {
        "name"         = pool.name
        "region"       = pool.region
        "instanceType" = pool.instance_type
        "maxSize"      = pool.max_size
        "minSize"      = pool.min_size
      }
    ]
    "image" : {
      "repository" = var.image_repository
      "tag"        = var.image_tag
    }
    "extraArgs" : var.extra_args,
    "extraEnv" = {
      "HCLOUD_TOKEN"          = var.hcloud_token
      "HCLOUD_CLUSTER_CONFIG" = base64encode(jsonencode(local.hcloud_cluster_config))
      # NOTE(@NiklasRosenstein): Despite the README of the Hetzner autoscaler v1.29.0 saying that the new
      #   HCLOUD_CLUSTER_CONFIG replaces HCLOUD_CLOUD_INIT, the variable must still be set, or autoscaler will fail
      #   to start.
      "HCLOUD_CLOUD_INIT" = "runcmd: []"
      "HCLOUD_FIREWALL"   = var.hcloud_firewall
      "HCLOUD_NETWORK"    = var.hcloud_network
      "HCLOUD_SSH_KEY"    = var.hcloud_ssh_key
    },
  })]
}

resource "kubernetes_deployment_v1" "cluster-autoscaler-test" {
  depends_on = [helm_release.cluster-autoscaler]
  for_each   = var.install_scale_test_deployments ? toset([for pool in var.node_pools : pool.name]) : toset([])
  metadata {
    name      = "${var.release_name}-${each.key}"
    namespace = var.namespace
  }
  spec {
    replicas = 0
    selector {
      match_labels = { "app" = "${var.release_name}-${each.key}" }
    }
    template {
      metadata {
        labels = { "app" = "${var.release_name}-${each.key}" }
      }
      spec {
        dynamic "toleration" {
          for_each = local.node_pool_taints[each.key]
          content {
            key      = toleration.value.key
            value    = toleration.value.value
            operator = "Equal"
            effect   = "NoSchedule"
          }
        }
        node_selector = local.node_pool_labels[each.key]
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              topology_key = "kubernetes.io/hostname"
              label_selector {
                match_labels = { "app" = "${var.release_name}-${each.key}" }
              }
            }
          }
        }
        container {
          name    = "idle"
          image   = "alpine"
          command = ["/bin/sh", "-c", "tail -f /dev/null"]
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}
