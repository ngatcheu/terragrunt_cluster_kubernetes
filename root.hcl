# ==============================================================================
# Configuration racine Terragrunt — incluse par TOUTES les unités (live/**).
#   - backend du state (local par défaut, S3/MinIO via TG_STATE_BACKEND=s3)
#   - contraintes de versions
#   - exclusion des environnements désactivés
#   - retry sur les erreurs transitoires
# Secrets : lus par Terraform dans les variables d'environnement TF_VAR_*
#   (TF_VAR_proxmox_password, TF_VAR_github_token).
# ==============================================================================

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  # ----- State -----
  state_backend = get_env("TG_STATE_BACKEND", local.common.state.backend)
  state_key     = "${path_relative_to_include()}/terraform.tfstate"

  backend_configs = {
    local = {
      path = "${get_parent_terragrunt_dir()}/.terragrunt-state/${local.state_key}"
    }
    # Compatible MinIO / Ceph RGW / Garage. Verrouillage natif S3 (Terraform >= 1.10).
    s3 = {
      bucket                      = local.common.state.s3.bucket
      key                         = local.state_key
      region                      = local.common.state.s3.region
      endpoints                   = { s3 = local.common.state.s3.endpoint }
      use_path_style              = true
      use_lockfile                = true
      skip_credentials_validation = true
      skip_region_validation      = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_s3_checksum            = true
      # Terragrunt ne tente pas de créer/configurer le bucket (non supporté hors AWS).
      disable_init = true
    }
  }
}

remote_state {
  backend = local.state_backend
  config  = local.backend_configs[local.state_backend]

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform_version_constraint  = ">= 1.10.0"
terragrunt_version_constraint = ">= 1.0.0"

# Un environnement avec `enabled = false` dans son env.hcl est ignoré par toutes
# les commandes (y compris un `terragrunt run --all` lancé depuis live/).
exclude {
  if                   = !local.env.enabled
  actions              = ["all"]
  exclude_dependencies = false
}

errors {
  retry "transient" {
    retryable_errors = [
      "(?s).*Error installing provider.*(TLS handshake timeout|connection reset by peer).*",
      "(?s).*Failed to load state.*(timeout|connection reset).*",
      "(?s).*can't lock file.*got timeout.*",
      # Proxmox saturé par des tâches simultanées (clone/destroy en parallèle)
      "(?s).*got no worker upid.*",
      "(?s).*start worker failed.*",
      "(?s).*error: connection refused.*8006.*",
    ]
    max_attempts       = 3
    sleep_interval_sec = 10
  }
}
