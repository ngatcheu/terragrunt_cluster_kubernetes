# proxmox-vm-template

Crée par SSH, sur l'hyperviseur, un template cloud-init à partir d'une image qcow2
(Rocky Linux 9 par défaut). Le script est rendu via `templatefile` et reste **idempotent** :
il sort sans rien faire si l'ID existe déjà.

- Aucun provider requis (`terraform_data` + provisioners)
- Authentification SSH par clé (`proxmox_ssh_private_key_file`) ou mot de passe
- Un changement de paramètre remplace la ressource, mais **ne reconstruit pas** un template existant

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
