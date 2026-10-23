output "nodes" {
  description = "Nœuds provisionnés (rôle, IP sans masque, ID Proxmox)"
  value = {
    for name, node in var.nodes : name => {
      vm_id = module.vms[name].vm_id
      ip    = split("/", module.vms[name].ip_address)[0]
      role  = node.role
    }
  }
}

output "vm_names" {
  description = "Noms de toutes les VMs"
  value       = [for vm in module.vms : vm.name]
}

output "vm_ids" {
  description = "IDs de toutes les VMs"
  value       = [for vm in module.vms : vm.vm_id]
}

output "ip_addresses" {
  description = "IPs (CIDR) de toutes les VMs"
  value       = [for vm in module.vms : vm.ip_address]
}
