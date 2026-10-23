# ==============================================================================
# Unité "fluxcd" — bootstrap FluxCD (GitOps) sur le cluster RKE2.
# Données : live/<env>/<cluster>/cluster.hcl (bloc flux).
# Prérequis : RKE2 installé via Ansible (make rke2-install), qui dépose
#             live/<env>/<cluster>/rke2/kubeconfig.yaml.
# Secret attendu : github_token (variable d'environnement TF_VAR_github_token).
# ==============================================================================

locals {
  root_dir    = dirname(find_in_parent_folders("root.hcl"))
  cluster_dir = dirname(find_in_parent_folders("cluster.hcl"))
  common      = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  cluster     = read_terragrunt_config(find_in_parent_folders("cluster.hcl")).locals

  github_owner    = local.common.github.owner
  repository      = local.cluster.flux.repository
  branch          = try(local.cluster.flux.branch, local.common.github.branch)
  kubeconfig_path = "${local.cluster_dir}/rke2/kubeconfig.yaml"
}

terraform {
  source = "${local.root_dir}/modules//flux-bootstrap"
}

# Ordre uniquement : RKE2 (Ansible) s'exécute entre vms et fluxcd, hors Terragrunt.
dependencies {
  paths = ["../vms"]
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "github_token" {
      description = "GitHub PAT (scope repo) utilisé par Flux et le provider GitHub"
      type        = string
      sensitive   = true
    }

    variable "kubeconfig_path" {
      description = "Kubeconfig du cluster cible (rapatrié par Ansible dans ../rke2/)"
      type        = string
    }

    provider "github" {
      owner = "${local.github_owner}"
      token = var.github_token
    }

    provider "flux" {
      kubernetes = {
        config_path    = var.kubeconfig_path
        config_context = "${try(local.cluster.flux.kube_context, "default")}"
      }
      git = {
        url    = "https://github.com/${local.github_owner}/${local.repository}.git"
        branch = "${local.branch}"
        http = {
          username = "git"
          password = var.github_token
        }
      }
    }
  EOF
}

inputs = {
  github_owner            = local.github_owner
  github_repository       = local.repository
  flux_bootstrap_git_path = local.cluster.flux.path
  components_extra        = try(local.cluster.flux.components_extra, null)
  kubeconfig_path         = local.kubeconfig_path
}
