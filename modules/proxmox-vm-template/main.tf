locals {
  script = templatefile("${path.module}/templates/create-template.sh.tftpl", {
    template_vm_id  = var.template_vm_id
    template_name   = var.template_name
    storage         = var.storage
    memory          = var.memory
    cores           = var.cores
    network_bridge  = var.network_bridge
    image_url       = var.image_url
    cloud_init_user = var.cloud_init_user
  })
  remote_script_path = "/tmp/create-template-${var.template_vm_id}.sh"
}

# Le script est idempotent (sort si le template existe déjà) : un replace de cette
# ressource ne reconstruit pas le template. Pour forcer une reconstruction, supprimer
# le template dans Proxmox puis `terragrunt apply -replace=terraform_data.template`.
resource "terraform_data" "template" {
  triggers_replace = {
    script_sha     = sha256(local.script)
    template_vm_id = var.template_vm_id
    proxmox_host   = var.proxmox_host
  }

  connection {
    type        = "ssh"
    host        = var.proxmox_host
    user        = var.proxmox_ssh_user
    password    = var.proxmox_ssh_private_key_file == null ? var.proxmox_password : null
    private_key = var.proxmox_ssh_private_key_file == null ? null : file(var.proxmox_ssh_private_key_file)
  }

  provisioner "file" {
    content     = local.script
    destination = local.remote_script_path
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0700 ${local.remote_script_path}",
      local.remote_script_path,
      "rm -f ${local.remote_script_path}",
    ]
  }

  lifecycle {
    precondition {
      condition     = var.proxmox_password != null || var.proxmox_ssh_private_key_file != null
      error_message = "Fournir proxmox_password ou proxmox_ssh_private_key_file pour la connexion SSH à Proxmox."
    }
  }
}
