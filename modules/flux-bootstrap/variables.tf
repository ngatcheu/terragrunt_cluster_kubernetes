variable "github_owner" {
  description = "Propriétaire du repository GitOps (utilisateur ou organisation)"
  type        = string
}

variable "github_repository" {
  description = "Nom du repository GitOps"
  type        = string
}

variable "flux_bootstrap_git_path" {
  description = "Chemin du cluster dans le repository GitOps (ex: /clusters/cluster-payload)"
  type        = string
}

variable "components_extra" {
  description = "Composants Flux additionnels (ex: [\"image-reflector-controller\", \"image-automation-controller\"])"
  type        = list(string)
  default     = null
}
