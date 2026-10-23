# Staging n'est pas encore provisionné (les inventaires staging historiques sont vides).
# Passer enabled = true après avoir validé les valeurs de staging/*/cluster.hcl.
locals {
  environment = "staging"
  enabled     = false
}
