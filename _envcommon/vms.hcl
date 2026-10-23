# ==============================================================================
# Unité "vms" — VMs du cluster sur Proxmox (clones du template Rocky 9).
# Données : live/<env>/<cluster>/cluster.hcl (bloc nodes).
# Secret attendu : proxmox_password (variable d'environnement TF_VAR_proxmox_password).
# ==============================================================================

locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
  common   = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  cluster  = read_terragrunt_config(find_in_parent_folders("cluster.hcl")).locals

  parallelism = try(local.cluster.proxmox_parallelism, 2)
}

terraform {
  source = "${local.root_dir}/modules//k8s-nodes"

  # Limite les clones simultanés : Proxmox verrouille le template pendant un clone.
  extra_arguments "parallelism" {
    commands  = ["plan", "apply", "destroy"]
    arguments = ["-parallelism=${local.parallelism}"]
  }
}

dependency "template" {
  config_path = "${local.root_dir}/live/shared/proxmox-template"

  mock_outputs = {
    template_vm_id = local.common.template.vm_id
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "state"]
}

# Provider généré ici (et non dans le module) pour garder le module composable.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "proxmox_password" {
      description = "Mot de passe de l'API Proxmox (${local.common.proxmox.api_username})"
      type        = string
      sensitive   = true
    }

    provider "proxmox" {
      endpoint = "https://${local.common.proxmox.host}:8006"
      username = "${local.common.proxmox.api_username}"
      password = var.proxmox_password
      insecure = ${local.common.proxmox.insecure}
    }
  EOF
}

inputs = {
  cluster_name   = local.cluster.cluster_name
  proxmox_node   = local.common.proxmox.node
  template_vm_id = dependency.template.outputs.template_vm_id

  network_bridge = local.common.network.bridge
  gateway        = local.common.network.gateway
  nameserver     = local.common.network.nameserver
  ssh_public_key = local.common.ssh_public_key

  nodes = local.cluster.nodes
}
