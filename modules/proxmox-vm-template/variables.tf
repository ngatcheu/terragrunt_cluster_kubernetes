# ===== Connexion SSH à l'hyperviseur =====

variable "proxmox_host" {
  description = "Adresse IP ou FQDN du serveur Proxmox"
  type        = string
}

variable "proxmox_ssh_user" {
  description = "Utilisateur SSH sur l'hyperviseur (doit pouvoir exécuter `qm`)"
  type        = string
  default     = "root"
}

variable "proxmox_password" {
  description = "Mot de passe SSH de l'hyperviseur (ignoré si proxmox_ssh_private_key_file est défini)"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_ssh_private_key_file" {
  description = "Chemin vers la clé privée SSH de l'hyperviseur (recommandé plutôt que le mot de passe)"
  type        = string
  default     = null
}

# ===== Template =====

variable "template_vm_id" {
  description = "ID Proxmox du template"
  type        = number
  default     = 9100

  validation {
    condition     = var.template_vm_id >= 100 && var.template_vm_id <= 999999999
    error_message = "template_vm_id doit être compris entre 100 et 999999999 (contrainte Proxmox)."
  }
}

variable "template_name" {
  description = "Nom du template dans Proxmox"
  type        = string
  default     = "rocky-9-cloud-template"
}

variable "image_url" {
  description = "URL de l'image cloud qcow2 utilisée pour construire le template"
  type        = string
  default     = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
}

variable "storage" {
  description = "Stockage Proxmox recevant le disque du template"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Bridge réseau de l'interface net0"
  type        = string
  default     = "vmbr0"
}

variable "memory" {
  description = "RAM du template en MB (surchargée au clonage)"
  type        = number
  default     = 2048
}

variable "cores" {
  description = "vCPUs du template (surchargés au clonage)"
  type        = number
  default     = 2
}

variable "cloud_init_user" {
  description = "Utilisateur cloud-init par défaut"
  type        = string
  default     = "root"
}
