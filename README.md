# Cluster Autoscaler for K3s on Hetzner Cloud

This Terraform module deploys a [kubernetes/autoscaler](https://github.com/kubernetes/autoscaler) for use with a K3s cluster running in Hetzner cloud. The module is tested with a cluster created via [hetzner-k3s](https://github.com/vitobotta/hetzner-k3s), which as of the time of writing does not support labels/taints for node pools (see [#317](https://github.com/vitobotta/hetzner-k3s/issues/317)), but will likely work with other K3s clusters as well.

> __Note__: This modules _includes_ the Helm chart in version 9.36.0 from [kubernetes/autoscaler#6502](https://github.com/kubernetes/autoscaler/pull/6502) which added support for Hetzner Cloud in the chart values.

__External links__

* [Cluster autoscaler for Hetzner Cloud README](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/hetzner/README.md)
* [Helm chart source](https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler)
* [Helm chart on ArtifactHub.io](https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler)

__Table of contents__

<!-- toc -->
* [Usage example](#usage-example)
* [Performance](#performance)
* [Troubleshooting tips](#troubleshooting-tips)
  * [Inspect the generated cloud-init](#inspect-the-generated-cloud-init)
  * [The scale test deployments don't differentiate between architectures](#the-scale-test-deployments-dont-differentiate-between-architectures)
* [Development](#development)
* [Documentation](#documentation)
  * [Requirements](#requirements)
  * [Providers](#providers)
  * [Modules](#modules)
  * [Resources](#resources)
  * [Inputs](#inputs)
  * [Outputs](#outputs)
<!-- end toc -->

## Usage example

```hcl
locals {
  hk3s_config = yamldecode(file("${path.module}/../cluster/config.yaml"))
}

module "cluster-autoscaler" {
  source  = "NiklasRosenstein/terraform-helm-hcloud-k3s-cluster-autoscaler"
  version = "~> 0.1"

  hcloud_token    = var.hcloud_token
  hcloud_network  = local.hk3s_config["cluster_name"]
  hcloud_firewall = local.hk3s_config["cluster_name"]
  hcloud_ssh_key  = local.hk3s_config["cluster_name"]
  k3s_version     = local.hk3s_config["k3s_version"]
  k3s_token       = var.k3s_token

  node_pools = [
    {
      name          = "amd64-small"
      region        = "hel1"
      instance_type = "cpx21"
      min_size      = 0
      max_size      = 8
      labels        = ["foo/bar=small"]
      taints        = ["role=mynodepool:NoSchedule"]
    }
  ]

  install_scale_test_deployments = true
}
```

## Performance

A small-scale test using a CPX21 node-pool in the HEL1 region showed that new nodes can come up and pods being
scheduled in under 60 seconds.

## Troubleshooting tips

### Inspect the generated cloud-init

You have two options: (1) Either retrieve the `Deployment` resource to dump it's YAML and extract the
`HCLOUD_CLUSTER_CONFIG` value to decode it, or (2) you add a Terraform `output {}` block to your root module
that exports this module and use `terraform output` to inspect the contents of the `hcloud_cluster_config`.

Example:

```
$ terraform output -json cluster-autoscaler | jq '.hcloud_cluster_config.nodeConfigs."my-nodepool".cloudInit' -r
```

### The scale test deployments don't differentiate between architectures

Only the `labels` specified in the node pool configuration are passed into the test Deployments. You can simply
add the `kubernetes.io/arch` label explicitly and set the value to `amd64` or `arm64`, respectively.

## Development

Install [pre-commit](https://pre-commit.com/) as well as the following tools to complete the checks:

* Terraform (duh!)
* [mksync](https://pypi.org/project/mksync/)
* [terraform-docs](https://github.com/terraform-docs/terraform-docs)

## Documentation

<!-- runcmd terraform-docs markdown . --indent=3 -->
### Requirements

No requirements.

### Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.12.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.25.2 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [helm_release.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_deployment_v1.cluster-autoscaler-test](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | n/a | `bool` | `false` | no |
| <a name="input_hcloud_firewall"></a> [hcloud\_firewall](#input\_hcloud\_firewall) | The name of the Hetzner cloud firewall to attach to nodes. | `string` | `null` | no |
| <a name="input_hcloud_image_amd64"></a> [hcloud\_image\_amd64](#input\_hcloud\_image\_amd64) | The Hetzner cloud image to use for creating amd64 nodes (can be an image ID, name, or a label selector). | `string` | `"ubuntu-22.04"` | no |
| <a name="input_hcloud_image_arm64"></a> [hcloud\_image\_arm64](#input\_hcloud\_image\_arm64) | The Hetzner cloud image to use for creating arm64 nodes (can be an image ID, name, or a label selector). | `string` | `"ubuntu-22.04"` | no |
| <a name="input_hcloud_network"></a> [hcloud\_network](#input\_hcloud\_network) | The name of the Hetzner cloud network to attach nodes to. | `string` | `null` | no |
| <a name="input_hcloud_ssh_key"></a> [hcloud\_ssh\_key](#input\_hcloud\_ssh\_key) | The name of the Hetzner cloud SSH key to use when creating nodes. | `string` | `null` | no |
| <a name="input_hcloud_token"></a> [hcloud\_token](#input\_hcloud\_token) | The Hetzner cloud token to provision new nodes. | `string` | n/a | yes |
| <a name="input_image_repository"></a> [image\_repository](#input\_image\_repository) | The repository for the cluster autoscaler container image. | `string` | `"registry.k8s.io/autoscaling/cluster-autoscaler"` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | The tag of the cluster autoscaler container image to use. The minimum version required is `v1.29.0`. | `string` | `"v1.29.0"` | no |
| <a name="input_install_scale_test_deployments"></a> [install\_scale\_test\_deployments](#input\_install\_scale\_test\_deployments) | Whether to install a `Deployment` for each node pool that can be used to test scaling it. | `bool` | `false` | no |
| <a name="input_k3s_installer_url"></a> [k3s\_installer\_url](#input\_k3s\_installer\_url) | The URL to fetch the K3s installer script from. | `string` | `"https://get.k3s.io"` | no |
| <a name="input_k3s_token"></a> [k3s\_token](#input\_k3s\_token) | The token to register the new node into K3s. | `string` | n/a | yes |
| <a name="input_k3s_url"></a> [k3s\_url](#input\_k3s\_url) | The URL where the Kubernetes control plane is reachable, ideally using a private IP. The defalt value<br>of `10.0.0.2` will work in most cases for a new K3s cluster where one of the master nodes was created<br>as the first node in the network using a default CIDR. | `string` | `"https://10.0.0.2:6443"` | no |
| <a name="input_k3s_version"></a> [k3s\_version](#input\_k3s\_version) | The K3s version to install when provisioning a new node. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to deploy the Helm chart to. | `string` | `"kube-system"` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | n/a | <pre>list(object({<br>    name          = string<br>    region        = string<br>    instance_type = string<br>    min_size      = number<br>    max_size      = number<br>    labels        = optional(list(string), [])<br>    taints        = optional(list(string), [])<br>  }))</pre> | `[]` | no |
| <a name="input_private_network_gateway_ip"></a> [private\_network\_gateway\_ip](#input\_private\_network\_gateway\_ip) | The IP of the gateway for the private network that the scaled nodes will be provisioned in. This is<br>needed to properly determine the node's private IP address. Defaults to `10.0.0.1` which should be<br>correct in most scenarios unless you change the default Hetzner cloud network CIDR. | `string` | `"10.0.0.1"` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | n/a | `string` | `"cluster-autoscaler"` | no |
| <a name="input_sshd_config"></a> [sshd\_config](#input\_sshd\_config) | Additional configuration values for the SSH daemon. | `string` | `"Port 22\nPasswordAuthentication no\nX11Forwarding no\nMaxAuthTries 2\nAllowTcpForwarding no\nAllowAgentForwarding no\nPubkeyAcceptedKeyTypes=+ssh-rsa\n"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_hcloud_cluster_config"></a> [hcloud\_cluster\_config](#output\_hcloud\_cluster\_config) | n/a |
<!-- end runcmd -->
