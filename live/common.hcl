# ==============================================================================
# Valeurs communes à tous les environnements et clusters (non sensibles).
# Les secrets passent par les variables d'environnement TF_VAR_*.
# ==============================================================================

locals {
  proxmox = {
    host         = "192.168.1.100"
    node         = "proxmox"
    api_username = "root@pam"
    ssh_user     = "root"
    insecure     = true # certificat auto-signé de l'hyperviseur
  }

  network = {
    bridge     = "vmbr0"
    gateway    = "192.168.1.1"
    nameserver = "192.168.1.1"
  }

  template = {
    vm_id     = 9100
    name      = "rocky-9-cloud-template"
    storage   = "local-lvm"
    image_url = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  }

  # Clé publique injectée par cloud-init (root) sur toutes les VMs.
  ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaHjlYm77/7UDnQxsl6kd+cLcN8ZKxdqqJ/3qepSjmYuPK5AZjTc8r9XzUiYjzTtD3rt6tvr4LkXF5hPC0FAc0trjSlqwPzsqtCVh4Zk7YQhf4pYoznMs19eSQibM4n4dZogRhc4CoZf8+bAOLboHD2vdqy+mRE4rI6EdykXQC7BQ6TMzQoRE7l+nT1o38wX/FpNdcovT7CaCJUOm+6Gg8Y0aNUZax/Vg3C7ZbUSJIbvvJLaqiBbsQRs/sbX8iOyftng1yxQPxWJgA1JXYKjrrSsZQkPjdP0HXuywqu8fYFAToEld7szmuTa0qj+woKPoCXzgwaO76/l7qFv3iC/gPd9zaVqtIznycI6vX5gnj8XvMs1HRNS3o/ElyMWgWeeNdvqSwyJWihNrd70spMTvC5JzfglgwXuzIMq6mlbEh6YQvN7SSaH4WEOcNF5/yXjIfDZxg246tMDbQ9JjdQ3QzLq7Kuwdtx/LAhyITpcfbweIPXkWHGuRvjkGX0L7ieFU= nsfab@gaby"

  github = {
    owner  = "ngatcheu"
    branch = "main"
  }

  # Backend du state : "local" (défaut) ou "s3" (MinIO...). Surcharge : TG_STATE_BACKEND.
  # Identifiants S3 : AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
  state = {
    backend = "local"
    s3 = {
      bucket   = "terraform-state"
      region   = "us-east-1"
      endpoint = "https://minio.homelab.local:9000"
    }
  }
}
