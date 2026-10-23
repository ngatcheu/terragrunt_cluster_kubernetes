# Les providers `github` et `flux` sont configurés par Terragrunt
# (_envcommon/fluxcd.hcl, bloc generate "provider") : le module reste réutilisable.

# Échoue tôt si le repository GitOps n'existe pas ou si le token n'y a pas accès.
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.github_repository}"
}

resource "flux_bootstrap_git" "this" {
  path             = var.flux_bootstrap_git_path
  components_extra = var.components_extra
}
