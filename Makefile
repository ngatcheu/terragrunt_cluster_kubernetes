# ==============================================================================
# Point d'entrée opérateur — mêmes cibles que les anciens repos datacenter-kubernetes-*,
# avec CLUSTER=rancher|payload pour choisir le cluster.
#   make help
#   make infra-apply  CLUSTER=payload
#   make rke2-install CLUSTER=payload
#   make fluxcd-apply CLUSTER=payload
# ==============================================================================

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Secrets locaux (TF_VAR_*), ignorés par Git — modèle : .env.example
-include .env
export

ENV     ?= production
CLUSTER ?= payload
TG      ?= terragrunt

CLUSTER_DIR := live/$(ENV)/$(CLUSTER)
INFRA_DIR   := $(CLUSTER_DIR)/vms
RKE2_DIR    := $(CLUSTER_DIR)/rke2
FLUXCD_DIR  := $(CLUSTER_DIR)/fluxcd

# Cache de providers partagé entre unités (Terragrunt >= 1.0).
export TG_PROVIDER_CACHE ?= 1

# Sous WSL, /mnt/c est « world writable » : Ansible y ignore le ansible.cfg du
# répertoire courant. Un chemin explicite est, lui, toujours pris en compte.
export ANSIBLE_CONFIG := $(CURDIR)/$(RKE2_DIR)/ansible.cfg

.PHONY: help check-cluster check-rke2 \
        template infra-init infra-plan infra-apply infra-destroy \
        rke2-deps rke2-install rke2-uninstall rke2-update rke2-reboot rke2-maintenance \
        rke2-longhorn-prereqs rke2-backup rke2-restore \
        fluxcd-init fluxcd-plan fluxcd-apply fluxcd-destroy \
        ca-export ca-distribute \
        plan-all graph fmt fmt-check validate lint secure-perms \
        backup-state backup-list

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables : ENV=$(ENV) CLUSTER=$(CLUSTER)"

check-cluster:
	@test -f $(CLUSTER_DIR)/cluster.hcl || { echo "Cluster inconnu : $(CLUSTER_DIR)"; exit 1; }

check-rke2: check-cluster
	@test -d $(RKE2_DIR) || { echo "Dossier Ansible absent : $(RKE2_DIR)"; exit 1; }

# ==============================================================================
# 0. TEMPLATE - Terragrunt (partagé par tous les clusters)
# ==============================================================================

template: ## Créer le template Rocky 9 (live/shared/proxmox-template)
	cd live/shared/proxmox-template && $(TG) apply

# ==============================================================================
# 1. INFRA - Terragrunt (Proxmox)
# ==============================================================================

infra-init: check-cluster ## Initialiser l'unité vms
	cd $(INFRA_DIR) && $(TG) init

infra-plan: check-cluster ## Planifier le provisionnement des VMs
	cd $(INFRA_DIR) && $(TG) plan

infra-apply: check-cluster ## Provisionner les VMs sur Proxmox
	cd $(INFRA_DIR) && $(TG) apply

infra-destroy: check-cluster ## Détruire les VMs
	cd $(INFRA_DIR) && $(TG) destroy

# ==============================================================================
# 2. RKE2 - Ansible (dossier rke2/ d'origine, ENV=staging|production)
# ==============================================================================

rke2-deps: check-rke2 ## Installer les collections Ansible requises
	cd $(RKE2_DIR) && ansible-galaxy collection install -r collections/requirements.yml

rke2-install: check-rke2 ## Installer le cluster RKE2
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml install_rke2.yml -e "ENVIRONNEMENT=$(ENV)"

rke2-uninstall: check-rke2 ## Désinstaller le cluster RKE2
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml uninstall_rke2.yml -e "confirm_uninstall=yes"

rke2-update: check-rke2 ## Mettre à jour les VMs
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml update-vms.yml

rke2-reboot: check-rke2 ## Redémarrer les nœuds
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml reboot.yml

rke2-maintenance: check-rke2 ## Tâches de maintenance
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml node-maintenance-tasks.yml

rke2-longhorn-prereqs: check-rke2 ## Installer les prérequis Longhorn (payload)
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml longhorn-prereqs.yml

SNAPSHOT ?= latest

rke2-backup: check-rke2 ## Sauvegarder etcd + credentials (SNAPSHOT=nom ou latest, payload)
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml rke2_backup.yml -e "backup_name=$(SNAPSHOT)"

rke2-restore: check-rke2 ## Restaurer depuis un snapshot (SNAPSHOT=nom-du-snapshot, payload)
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml rke2_restore.yml -e "rke2_etcd_snapshot_file=$(SNAPSHOT)"

# ==============================================================================
# 3. FLUXCD - Terragrunt (GitOps) — lit $(RKE2_DIR)/kubeconfig.yaml
# ==============================================================================

fluxcd-init: check-cluster ## Initialiser l'unité fluxcd
	cd $(FLUXCD_DIR) && $(TG) init -upgrade

fluxcd-plan: check-cluster ## Planifier le bootstrap FluxCD
	cd $(FLUXCD_DIR) && $(TG) plan

fluxcd-apply: check-cluster ## Bootstrapper FluxCD sur le cluster
	cd $(FLUXCD_DIR) && $(TG) apply

fluxcd-destroy: check-cluster ## Supprimer FluxCD du cluster
	cd $(FLUXCD_DIR) && $(TG) destroy

# ==============================================================================
# 4. CA HOMELAB - Après fluxcd-apply (cert-manager génère la CA)
# ==============================================================================

ca-export: check-rke2 ## Exporter la CA depuis le cluster vers le répertoire local
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml homelab-ca.yml --tags export

ca-distribute: check-rke2 ## Distribuer la CA dans le trust store des nodes
	cd $(RKE2_DIR) && ansible-playbook -i inventory-$(ENV).yml homelab-ca.yml --tags distribute

# ==============================================================================
# Global / qualité
# ==============================================================================

plan-all: ## Planifier toutes les unités Terragrunt actives
	cd live && $(TG) run --all plan

graph: ## Graphe de dépendances Terragrunt (format DOT)
	cd live && $(TG) dag graph

fmt: ## Formater HCL Terraform + Terragrunt
	terraform fmt -recursive modules
	$(TG) hcl fmt

fmt-check: ## Vérifier le formatage (CI)
	terraform fmt -recursive -check modules
	$(TG) hcl fmt --check

validate: ## Valider toutes les unités Terragrunt
	cd live && $(TG) run --all validate

lint: ## tflint sur les modules
	tflint --init
	tflint --recursive --chdir=modules

# ==============================================================================
# Sécurité locale — nécessite l'option `metadata` sur /mnt/c (voir README)
# ==============================================================================

secure-perms: ## Restreindre les permissions (600/700) des secrets, states et kubeconfigs
	@chmod 600 .env 2>/dev/null || true
	@test -d .terragrunt-state && find .terragrunt-state -type d -exec chmod 700 {} + && find .terragrunt-state -type f -exec chmod 600 {} + || true
	@find live -path '*/rke2/*' \( -name kubeconfig.yaml -o -name 'homelab-ca.key' \) -exec chmod 600 {} +
	@find live -path '*/rke2/backups' -type d -exec chmod -R go-rwx {} +
	@if [ "$$(stat -c %a .env 2>/dev/null)" = "600" ]; then echo "Permissions restreintes."; \
	 else echo "⚠ chmod sans effet : activer 'metadata' sur /mnt/c (voir README, section Sécurité locale)."; exit 1; fi

# ==============================================================================
# Sauvegarde chiffrée (gpg AES-256) des states, kubeconfigs et CA
#   make backup-state            -> $(BACKUP_DIR)/tg-state-<date>.tar.gz.gpg
#   Restauration : voir README, section « Sauvegarde »
# ==============================================================================

BACKUP_DIR  ?= $(HOME)/backups/terragrunt_cluster_kubernetes
BACKUP_KEEP ?= 10
# Automatisation : GPG_OPTS="--batch --pinentry-mode loopback --passphrase-file ~/.tg-backup-pass"
GPG_OPTS    ?=
BACKUP_FILE := $(BACKUP_DIR)/tg-state-$(shell date +%Y%m%d-%H%M%S).tar.gz.gpg

backup-state: ## Archiver + chiffrer states, kubeconfigs et CA hors du repo (BACKUP_DIR=...)
	@test -d .terragrunt-state || { echo "Aucun state à sauvegarder."; exit 1; }
	@install -d -m 700 $(BACKUP_DIR)
	@# pinentry doit savoir sur quel terminal demander la passphrase (sinon « Inappropriate ioctl »).
	@export GPG_TTY=$$(tty 2>/dev/null || true); \
	 gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true; \
	 files=".terragrunt-state $$(find live -path '*/rke2/*' \( -name kubeconfig.yaml -o -name 'homelab-ca.*' \) -not -name '*.yml' | sort)"; \
	 tar -czf - $$files | gpg $(GPG_OPTS) --symmetric --cipher-algo AES256 --output $(BACKUP_FILE) \
	 || { rm -f $(BACKUP_FILE); echo "Échec du chiffrement : aucune sauvegarde créée."; exit 1; }
	@chmod 600 $(BACKUP_FILE)
	@echo "Sauvegarde : $(BACKUP_FILE)"
	@ls -1t $(BACKUP_DIR)/tg-state-*.tar.gz.gpg | tail -n +$$(( $(BACKUP_KEEP) + 1 )) | xargs -r rm -v

backup-list: ## Lister les sauvegardes et leur contenu le plus récent
	@ls -lh $(BACKUP_DIR)/tg-state-*.tar.gz.gpg 2>/dev/null || echo "Aucune sauvegarde dans $(BACKUP_DIR)"
