output "repository_url" {
  description = "URL HTTPS du repository GitOps"
  value       = data.github_repository.this.html_url
}

output "bootstrap_path" {
  description = "Chemin du cluster dans le repository GitOps"
  value       = flux_bootstrap_git.this.path
}
