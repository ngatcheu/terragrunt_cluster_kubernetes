variable "cluster_name" {
  description = "Nom logique du cluster (rancher, payload, ...)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.cluster_name))
    error_message = "cluster_name doit être en minuscules (a-z, 0-9, -), 2 à 31 caractères."
  }
}

variable "proxmox_node" {
  description = "Nœud Proxmox hébergeant les VMs"
  type        = string
}

variable "template_vm_id" {
  description = "ID du template à cloner"
  type        = number
}

# ===== Réseau commun =====

variable "network_bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
}

variable "gateway" {
  description = "Passerelle IPv4"
  type        = string
}

variable "nameserver" {
  description = "Serveur DNS"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé SSH publique injectée par cloud-init"
  type        = string
  sensitive   = true
}

# ===== Nœuds =====

variable "nodes" {
  description = <<-EOT
    Nœuds du cluster, indexés par nom de VM Proxmox.
      role           : "server" (control-plane/etcd) ou "agent" (worker)
      ip_address     : IPv4 au format CIDR (ex: 192.168.1.113/24)
      memory         : RAM en MB ; disk_size en GB
  EOT
  type = map(object({
    role       = string
    vm_id      = number
    ip_address = string
    cpu_cores  = number
    memory     = number
    disk_size  = number
    datastore  = string
  }))

  validation {
    condition     = alltrue([for n in values(var.nodes) : contains(["server", "agent"], n.role)])
    error_message = "Chaque nœud doit avoir role = \"server\" ou \"agent\"."
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : can(cidrhost(n.ip_address, 0)) && strcontains(n.ip_address, "/")])
    error_message = "ip_address doit être une IPv4 au format CIDR, ex: 192.168.1.113/24."
  }

  validation {
    condition     = length(distinct([for n in values(var.nodes) : n.vm_id])) == length(var.nodes)
    error_message = "Les vm_id doivent être uniques au sein du cluster."
  }

  validation {
    condition     = length(distinct([for n in values(var.nodes) : n.ip_address])) == length(var.nodes)
    error_message = "Les ip_address doivent être uniques au sein du cluster."
  }

  validation {
    condition     = length([for n in values(var.nodes) : n if n.role == "server"]) % 2 == 1
    error_message = "Le nombre de nœuds server doit être impair (quorum etcd : 1, 3, 5...)."
  }
}
