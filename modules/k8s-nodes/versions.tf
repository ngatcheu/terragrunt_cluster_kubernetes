terraform {
  required_version = ">= 1.10.0"

  required_providers {
    # Doit rester aligné sur la contrainte du module proxmox-vm (terraform-vm-modules).
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.50.0"
    }
  }
}
