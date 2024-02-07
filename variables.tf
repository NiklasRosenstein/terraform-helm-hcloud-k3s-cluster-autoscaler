variable "namespace" {
  type        = string
  description = "The namespace to deploy the Helm chart to."
  default     = "kube-system"
}

variable "create_namespace" {
  type    = bool
  default = false
}

variable "release_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "image_repository" {
  type        = string
  description = "The repository for the cluster autoscaler container image."
  default     = "registry.k8s.io/autoscaling/cluster-autoscaler"
}

variable "image_tag" {
  type        = string
  description = "The tag of the cluster autoscaler container image to use. The minimum version required is `v1.29.0`."
  default     = "v1.29.0"
}

variable "private_network_gateway_ip" {
  type        = string
  description = <<-EOF
    The IP of the gateway for the private network that the scaled nodes will be provisioned in. This is
    needed to properly determine the node's private IP address. Defaults to `10.0.0.1` which should be
    correct in most scenarios unless you change the default Hetzner cloud network CIDR.
  EOF
  default     = "10.0.0.1"
}

variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "The Hetzner cloud token to provision new nodes."
}

variable "hcloud_image_amd64" {
  type        = string
  description = "The Hetzner cloud image to use for creating amd64 nodes (can be an image ID, name, or a label selector)."
  default     = "ubuntu-22.04"
}

variable "hcloud_image_arm64" {
  type        = string
  description = "The Hetzner cloud image to use for creating arm64 nodes (can be an image ID, name, or a label selector)."
  default     = "ubuntu-22.04"
}

variable "hcloud_firewall" {
  type        = string
  default     = null
  description = "The name of the Hetzner cloud firewall to attach to nodes."
}

variable "hcloud_network" {
  type        = string
  default     = null
  description = "The name of the Hetzner cloud network to attach nodes to."
}

variable "hcloud_ssh_key" {
  type        = string
  default     = null
  description = "The name of the Hetzner cloud SSH key to use when creating nodes."
}

variable "k3s_url" {
  type        = string
  description = <<-EOF
    The URL where the Kubernetes control plane is reachable, ideally using a private IP. The defalt value
    of `10.0.0.2` will work in most cases for a new K3s cluster where one of the master nodes was created
    as the first node in the network using a default CIDR.
  EOF
  default     = "https://10.0.0.2:6443"
}

variable "k3s_version" {
  type        = string
  description = "The K3s version to install when provisioning a new node."
}

variable "k3s_token" {
  type        = string
  sensitive   = true
  description = "The token to register the new node into K3s."
}

variable "k3s_installer_url" {
  type        = string
  description = "The URL to fetch the K3s installer script from."
  default     = "https://get.k3s.io"
}

variable "sshd_config" {
  type        = string
  description = "Additional configuration values for the SSH daemon."
  default     = <<-EOF
    Port 22
    PasswordAuthentication no
    X11Forwarding no
    MaxAuthTries 2
    AllowTcpForwarding no
    AllowAgentForwarding no
    PubkeyAcceptedKeyTypes=+ssh-rsa
  EOF
}

variable "node_pools" {
  type = list(object({
    name          = string
    region        = string
    instance_type = string
    min_size      = number
    max_size      = number
    labels        = optional(list(string), [])
    taints        = optional(list(string), [])
  }))
  default = []
}

variable "install_scale_test_deployments" {
  type        = bool
  description = "Whether to install a `Deployment` for each node pool that can be used to test scaling it."
  default     = false
}
