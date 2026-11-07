# ==============================================================================
# VMs STANDALONE (production) — VMs isolées, hors cluster Kubernetes.
# Réutilise l'unité vms/ (module k8s-nodes) : role = "server" n'a pas de sens
# ici, il satisfait seulement la validation du module (nombre impair de "server",
# les autres VMs passent donc en "agent").
# Pas de rke2/ ni de fluxcd/ : seules les cibles infra-* s'appliquent.
#   make infra-apply CLUSTER=standalone
# Dimensionnement : RAM restante de l'hôte après réduction des workers Payload
# (78,6 Go - 60 Go réservés), moins ~2,5 Go de marge pour l'hyperviseur.
# ==============================================================================

locals {
  cluster_name = "standalone"

  nodes = {
    # Floci (datacenter-floci)
    "standalone-1" = { role = "server", vm_id = 120, ip_address = "192.168.1.120/24", cpu_cores = 8, memory = 16384, disk_size = 200, datastore = "vms-data2" }
    # Pi-hole (pihole-dns) — DNS de tous les nœuds, IP .119 référencée partout
    "standalone-2" = { role = "agent", vm_id = 119, ip_address = "192.168.1.119/24", cpu_cores = 1, memory = 1024, disk_size = 20, datastore = "vms-data2" }
  }
}
