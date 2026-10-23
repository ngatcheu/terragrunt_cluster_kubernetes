# k8s-nodes

Provisionne les VMs d'un cluster Kubernetes en clonant un template, via le module
`terraform-vm-modules/proxmox-vm` (v1.0.2).

- `nodes` validé : rôle `server`/`agent`, IP CIDR, vm_id/IP uniques, nombre **impair** de servers (quorum etcd)
- Output `nodes` : rôle, IP sans masque et ID Proxmox de chaque VM
- Pas de bloc provider : il est généré par `_envcommon/vms.hcl`
- Adresse `module.vms[<nom>]` identique aux anciens repos (migration du state sans `state mv`)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
