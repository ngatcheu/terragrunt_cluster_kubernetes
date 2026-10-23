#!/usr/bin/env bash
# ==============================================================================
# Reprise des clusters existants depuis les anciens repos :
#   datacenter-kubernetes-rancher  -> live/production/rancher
#   datacenter-kubernetes-payload  -> live/production/payload
#
# Copie les states locaux (infra, fluxcd) vers le backend local Terragrunt,
# retire du state vms l'ancien null_resource du template (désormais dans
# live/shared/proxmox-template). Les dossiers rke2/ sont déjà copiés tels quels.
#
# Usage : scripts/migrate-legacy-state.sh [RÉPERTOIRE_DES_ANCIENS_REPOS]
#         (défaut : le répertoire parent de ce repo)
# Ensuite : `make plan ENV=production CLUSTER=<cluster>` doit n'afficher aucun
# changement sur vms ni fluxcd.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_ROOT="${1:-$(dirname "$ROOT")}"
STATE_ROOT="$ROOT/.terragrunt-state/live/production"

copy_state() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    echo "  - absent, ignoré : $src"
    return 0
  fi
  if [[ -f "$dst" ]]; then
    echo "  ! state déjà présent, non écrasé : $dst" >&2
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  chmod 0600 "$dst"
  echo "  ✓ $src -> $dst"
}

for cluster in rancher payload; do
  legacy="$LEGACY_ROOT/datacenter-kubernetes-$cluster/modules"
  echo "== $cluster (source : $legacy)"

  copy_state "$legacy/infra/terraform.tfstate"  "$STATE_ROOT/$cluster/vms/terraform.tfstate"
  copy_state "$legacy/fluxcd/terraform.tfstate" "$STATE_ROOT/$cluster/fluxcd/terraform.tfstate"

  # Le template est géré par live/shared/proxmox-template : on l'oublie ici
  # (state rm = aucune action sur Proxmox).
  vms_dir="$ROOT/live/production/$cluster/vms"
  if [[ -f "$STATE_ROOT/$cluster/vms/terraform.tfstate" ]] \
     && grep -q '"null_resource"' "$STATE_ROOT/$cluster/vms/terraform.tfstate"; then
    (cd "$vms_dir" && terragrunt state rm 'null_resource.rocky_template')
    echo "  ✓ null_resource.rocky_template retiré du state vms"
  fi
done

cat <<'EOF'

Migration terminée. Étapes suivantes :
  1. make infra-plan  CLUSTER=rancher   # aucune VM recréée attendue
  2. make fluxcd-plan CLUSTER=rancher
  3. idem avec CLUSTER=payload
  4. (optionnel) backend S3 : TG_STATE_BACKEND=s3 terragrunt run --all init -- -migrate-state
EOF
