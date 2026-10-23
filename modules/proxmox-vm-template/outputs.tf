output "template_vm_id" {
  description = "ID Proxmox du template, à cloner par les VMs"
  value       = var.template_vm_id
  # Garantit que le template existe avant tout clonage par une unité dépendante.
  depends_on = [terraform_data.template]
}

output "template_name" {
  description = "Nom du template"
  value       = var.template_name
}
