# ==============================================================================
# Cluster PAYLOAD (staging) — environnement désactivé (voir ../env.hcl).
# ⚠ VM IDs et IPs ci-dessous sont des PROPOSITIONS à valider avant activation.
# Avant activation : ajouter un dossier rke2/ (Ansible) à côté de vms/ et fluxcd/,
# fluxcd lit le kubeconfig dans ./rke2/kubeconfig.yaml.
# ==============================================================================

locals {
  cluster_name = "payload"

  nodes = {
    "payload-stg-master-1" = { role = "server", vm_id = 213, ip_address = "192.168.1.213/24", cpu_cores = 2, memory = 4096, disk_size = 40, datastore = "vms-ssd" }
    "payload-stg-worker-1" = { role = "agent", vm_id = 216, ip_address = "192.168.1.216/24", cpu_cores = 4, memory = 8192, disk_size = 100, datastore = "vms-raid" }
  }

  flux = {
    repository = "payload-gitops-fluxcd"
    path       = "/clusters/cluster-payload-staging"
  }
}
