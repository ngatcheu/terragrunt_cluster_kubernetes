# Le nom `module "vms"` et les clés de for_each sont conservés à l'identique des
# anciens repos datacenter-kubernetes-* : la migration du state se fait sans `state mv`.
module "vms" {
  for_each = var.nodes
  source   = "git@github.com:ngatcheu/terraform-vm-modules.git//proxmox-vm?ref=v1.0.2"

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = var.proxmox_node
  template_vm_id = var.template_vm_id

  cpu_cores    = each.value.cpu_cores
  memory       = each.value.memory
  disk_size    = each.value.disk_size
  datastore_id = each.value.datastore

  network_bridge = var.network_bridge
  ip_address     = each.value.ip_address
  gateway        = var.gateway
  nameserver     = var.nameserver
  ssh_public_key = var.ssh_public_key
}

# Avertissement (non bloquant) si une VM ne respecte pas la convention <cluster>-*.
check "vm_naming_convention" {
  assert {
    condition     = alltrue([for name in keys(var.nodes) : startswith(name, "${var.cluster_name}-")])
    error_message = "Les noms de VM devraient être préfixés par \"${var.cluster_name}-\"."
  }
}
