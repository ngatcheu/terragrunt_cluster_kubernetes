# ==============================================================================
# Cluster RANCHER (production) — plan de gestion : Rancher Manager.
# 3 nœuds server, VIP API 192.168.1.130.
# Ex-repo : datacenter-kubernetes-rancher
#   modules/infra  -> vms/      (Terragrunt)
#   modules/rke2   -> rke2/     (Ansible, copié tel quel)
#   modules/fluxcd -> fluxcd/   (Terragrunt)
# ==============================================================================

locals {
  cluster_name = "rancher"

  # ----- VMs Proxmox -----
  nodes = {
    "rancher-1" = { role = "server", vm_id = 110, ip_address = "192.168.1.110/24", cpu_cores = 4, memory = 8192, disk_size = 150, datastore = "vms-data1" }
    "rancher-2" = { role = "server", vm_id = 111, ip_address = "192.168.1.111/24", cpu_cores = 4, memory = 8192, disk_size = 150, datastore = "vms-data1" }
    "rancher-3" = { role = "server", vm_id = 112, ip_address = "192.168.1.112/24", cpu_cores = 4, memory = 8192, disk_size = 150, datastore = "vms-data1" }
  }

  # ----- FluxCD -----
  flux = {
    repository = "rancher-gitops-fluxcd"
    path       = "/clusters/cluster-rancher"
  }
}
