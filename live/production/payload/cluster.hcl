# ==============================================================================
# Cluster PAYLOAD (production) — charges de travail applicatives.
# 3 servers + 3 agents, VIP API 192.168.1.132.
# Ex-repo : datacenter-kubernetes-payload
#   modules/infra  -> vms/      (Terragrunt)
#   modules/rke2   -> rke2/     (Ansible, copié tel quel)
#   modules/fluxcd -> fluxcd/   (Terragrunt)
# ==============================================================================

locals {
  cluster_name = "payload"

  # Le clone de 6 VMs en parallèle sature le stockage : on limite à 2.
  proxmox_parallelism = 2

  # ----- VMs Proxmox -----
  nodes = {
    "payload-master-1" = { role = "server", vm_id = 113, ip_address = "192.168.1.113/24", cpu_cores = 4, memory = 4096, disk_size = 60, datastore = "vms-ssd" }
    "payload-master-2" = { role = "server", vm_id = 114, ip_address = "192.168.1.114/24", cpu_cores = 4, memory = 4096, disk_size = 60, datastore = "vms-ssd" }
    "payload-master-3" = { role = "server", vm_id = 115, ip_address = "192.168.1.115/24", cpu_cores = 4, memory = 4096, disk_size = 60, datastore = "vms-ssd" }
    "payload-worker-1" = { role = "agent", vm_id = 116, ip_address = "192.168.1.116/24", cpu_cores = 4, memory = 8192, disk_size = 200, datastore = "vms-raid" }
    "payload-worker-2" = { role = "agent", vm_id = 117, ip_address = "192.168.1.117/24", cpu_cores = 4, memory = 8192, disk_size = 200, datastore = "vms-raid" }
    "payload-worker-3" = { role = "agent", vm_id = 118, ip_address = "192.168.1.118/24", cpu_cores = 4, memory = 8192, disk_size = 200, datastore = "vms-raid" }
  }

  # ----- FluxCD -----
  flux = {
    repository = "payload-gitops-fluxcd"
    path       = "/clusters/cluster-payload"
  }
}
