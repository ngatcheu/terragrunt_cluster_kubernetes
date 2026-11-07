# terragrunt_cluster_kubernetes

Infrastructure as Code des clusters Kubernetes **RKE2** du datacenter Proxmox.
Ce repo unifie les deux anciens repos :

| Ancien repo                     | `modules/infra` | `modules/rke2` (Ansible)         | `modules/fluxcd` |
|---------------------------------|-----------------|----------------------------------|------------------|
| `datacenter-kubernetes-rancher` | `live/production/rancher/vms` | `live/production/rancher/rke2` | `live/production/rancher/fluxcd` |
| `datacenter-kubernetes-payload` | `live/production/payload/vms` | `live/production/payload/rke2` | `live/production/payload/fluxcd` |

- **infra** et **fluxcd** : le code Terraform, identique dans les deux repos, est écrit
  une seule fois dans `modules/`. Chaque cluster ne porte que ses valeurs (`cluster.hcl`).
- **rke2** : les dossiers Ansible d'origine sont **copiés tels quels** (playbooks,
  inventaires, `vars/`, CA, backups). Ils s'utilisent exactement comme avant.

---

## Architecture

```
live/shared/proxmox-template                 (Terragrunt — template Rocky 9, ID 9100)
        │
        ├──► production/rancher/vms          (Terragrunt — 3 VMs .110-.112)
        │         └─► rancher/rke2           (Ansible   — RKE2, kubeconfig.yaml)
        │                └─► rancher/fluxcd  (Terragrunt — lit ../rke2/kubeconfig.yaml)
        │
        ├──► production/payload/vms          (Terragrunt — 6 VMs .113-.118)
        │         └─► payload/rke2           (Ansible)
        │                └─► payload/fluxcd  (Terragrunt)
        │
        └──► production/standalone/vms       (Terragrunt — VMs isolées, .120)
```

| Cluster | Rôle                  | Nœuds                        | VIP API       | Repo GitOps             |
|---------|-----------------------|------------------------------|---------------|-------------------------|
| rancher | Rancher Manager       | 3 servers                    | 192.168.1.130 | `rancher-gitops-fluxcd` |
| payload | Workloads applicatifs | 3 servers + 3 agents         | 192.168.1.132 | `payload-gitops-fluxcd` |

`standalone` n'est pas un cluster : il regroupe des VMs isolées (`standalone-1`,
8 vCPU / 16 Go / 200 Go, `192.168.1.120`), sans RKE2 ni Flux. Il réutilise l'unité
`vms/` ; `role = "server"` y sert seulement à satisfaire la validation du module.

---

## Structure

```
terragrunt_cluster_kubernetes/
├── root.hcl                     # backend, contraintes de versions, exclude, retry
├── _envcommon/                  # logique commune à chaque type d'unité (DRY)
│   ├── proxmox-template.hcl
│   ├── vms.hcl                  #   + génère le provider proxmox
│   └── fluxcd.hcl               #   + génère les providers github / flux
├── modules/                     # modules Terraform réutilisables, sans bloc provider
│   ├── proxmox-vm-template/     #   ex null_resource + create-rocky9-template.sh
│   ├── k8s-nodes/               #   ex modules/infra
│   └── flux-bootstrap/          #   ex modules/fluxcd
├── live/
│   ├── common.hcl               # Proxmox, réseau, clé SSH, owner GitHub, backend
│   ├── shared/proxmox-template/
│   ├── production/
│   │   ├── env.hcl
│   │   ├── rancher/
│   │   │   ├── cluster.hcl      # nœuds + repo Flux
│   │   │   ├── vms/terragrunt.hcl
│   │   │   ├── rke2/            # ← copie exacte de datacenter-kubernetes-rancher/modules/rke2
│   │   │   └── fluxcd/terragrunt.hcl
│   │   ├── payload/             # idem (rke2/ = copie de datacenter-kubernetes-payload/modules/rke2)
│   │   └── standalone/          # VMs isolées : cluster.hcl + vms/ uniquement
│   └── staging/                 # enabled = false
├── scripts/migrate-legacy-state.sh
├── Makefile                     # mêmes cibles que les anciens repos + CLUSTER=
├── mise.toml                    # versions d'outils épinglées
└── .tflint.hcl .pre-commit-config.yaml .gitattributes .gitignore
```

Les dossiers `rke2/` n'ont pas de `terragrunt.hcl` : `terragrunt run --all` les ignore.

---

## Prérequis

- Outils épinglés dans `mise.toml` (`mise install`) : terraform 1.14.3, terragrunt 1.1.6, tflint 0.64.0
- `ansible` ≥ 2.10, `make` (Linux / WSL)
- Accès SSH à `github.com` (module `terraform-vm-modules`, collection Ansible)
- Accès SSH root à Proxmox et aux VMs

## Secrets

Aucun secret dans le repo : Terraform les lit dans les variables `TF_VAR_*`,
chargées depuis un fichier `.env` local (ignoré par Git) par le Makefile.

```bash
cp .env.example .env && chmod 600 .env   # renseigner TF_VAR_proxmox_password et TF_VAR_github_token
make infra-plan CLUSTER=payload
```

Le `.env` remplace les anciens `credentials.auto.tfvars` (infra) et
`secrets.auto.tfvars` (fluxcd), qui ne sont plus utilisés.

Les secrets Ansible restent où ils étaient : `rke2/vars/<env>/secrets.yaml`.

## State

| Mode           | Activation            | Emplacement                                        |
|----------------|-----------------------|----------------------------------------------------|
| local (défaut) | —                     | `.terragrunt-state/live/<env>/<cluster>/<unit>/`   |
| S3 / MinIO     | `TG_STATE_BACKEND=s3` | bucket `terraform-state` (`live/common.hcl`), verrou natif S3 |

## Sécurité locale (WSL)

`.env`, les states et les `rke2/kubeconfig.yaml` (certificat admin) sont sensibles.
Par défaut, WSL monte `/mnt/c` sans métadonnées POSIX : tout apparaît en `777`
et `chmod` est sans effet. À faire une fois :

```bash
sudo tee -a /etc/wsl.conf >/dev/null <<'EOF'

[automount]
options = "metadata,umask=022,fmask=011"
EOF
```

Puis, depuis PowerShell : `wsl --shutdown`, et rouvrir le terminal WSL. Ensuite :

```bash
make secure-perms    # .env, states, kubeconfigs, homelab-ca.key -> 600 ; .terragrunt-state -> 700
```

À relancer après chaque `rke2-install` ou `ca-export` (nouveaux fichiers sensibles).

## Sauvegarde

Le state local n'existe qu'à un seul endroit : le perdre, c'est perdre le pilotage
des VMs et de Flux. Sauvegarder après chaque `apply` :

```bash
make backup-state     # demande une passphrase ; archive gpg AES-256 dans ~/backups/terragrunt_cluster_kubernetes/
make backup-list
```

Contenu : `.terragrunt-state/`, `rke2/kubeconfig.yaml`, `rke2/homelab-ca.*`.
Les 10 dernières archives sont conservées (`BACKUP_KEEP=`). Copier régulièrement
`~/backups/` hors de la machine (NAS, disque externe) : une sauvegarde sur le même
disque ne protège que des erreurs de manipulation.

Automatisation (cron) sans saisie :

```bash
install -m 600 /dev/null ~/.tg-backup-pass && $EDITOR ~/.tg-backup-pass
make backup-state GPG_OPTS="--batch --pinentry-mode loopback --passphrase-file $HOME/.tg-backup-pass"
```

Restauration (depuis la racine du repo, après avoir vérifié le contenu) :

```bash
gpg -d ~/backups/terragrunt_cluster_kubernetes/tg-state-<date>.tar.gz.gpg | tar -tzf -   # lister
gpg -d ~/backups/terragrunt_cluster_kubernetes/tg-state-<date>.tar.gz.gpg | tar -xzf -   # restaurer
make secure-perms
```

---

## Utilisation

```bash
make help

make template                    # template Rocky 9 (une fois, partagé)

make infra-apply  CLUSTER=payload
make rke2-deps    CLUSTER=payload
make rke2-install CLUSTER=payload
make fluxcd-apply CLUSTER=payload
make ca-export ca-distribute CLUSTER=payload
```

VMs isolées : `make infra-plan|infra-apply|infra-destroy CLUSTER=standalone`
(les cibles `rke2-*` et `fluxcd-*` ne s'appliquent pas).

Toutes les cibles `rke2-*` et `ca-*` lancent les mêmes commandes qu'avant dans
`live/<env>/<cluster>/rke2/` (`ENV=production|staging` choisit `inventory-$(ENV).yml`).

Autres : `make plan-all`, `make graph`, `make fmt-check validate lint`.

---

## Migration depuis les anciens repos

```bash
scripts/migrate-legacy-state.sh ..     # copie les states infra/fluxcd, retire l'ancien null_resource
make infra-plan  CLUSTER=rancher
make fluxcd-plan CLUSTER=rancher
```

Adresses de ressources conservées (`module.vms["<nom>"]`, `flux_bootstrap_git.this`) :
aucune VM n'est recréée. Le seul diff in-place (`cpu.flags = []`, suppression de
`vga serial0`) existait déjà dans les anciens repos et vient de `terraform-vm-modules/proxmox-vm`.
