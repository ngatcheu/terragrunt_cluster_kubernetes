# ==============================================================================
# Unité "proxmox-template" — template Rocky Linux 9 cloné par toutes les VMs.
# Secret attendu : proxmox_password (variable d'environnement TF_VAR_proxmox_password).
# ==============================================================================

locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
  common   = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${local.root_dir}/modules//proxmox-vm-template"
}

inputs = {
  proxmox_host     = local.common.proxmox.host
  proxmox_ssh_user = local.common.proxmox.ssh_user

  template_vm_id = local.common.template.vm_id
  template_name  = local.common.template.name
  image_url      = local.common.template.image_url
  storage        = local.common.template.storage
  network_bridge = local.common.network.bridge
}
