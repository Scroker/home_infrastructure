# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible-based home lab automation for a Proxmox cluster running Fedora CoreOS VMs. The project is split into three independent, modular infrastructure areas, each with its own inventory, ansible.cfg, and playbooks.

## Running Playbooks

All playbooks are run from within their respective subdirectory, since `ansible.cfg` and `inventory` are local to each module.

```bash
# Standard execution
cd <module_dir>
ansible-playbook <playbook>.yml

# Via Ansible Navigator (uses execution environments)
cd <module_dir>
ansible-navigator run <playbook>.yml

# Limit to specific hosts
ansible-playbook <playbook>.yml --limit <host_or_group>

# Dry run
ansible-playbook <playbook>.yml --check

# Run specific tags
ansible-playbook <playbook>.yml --tags <tag>
```

Vault password is read from `.vault_pass` in each module directory (gitignored). To encrypt a variable:
```bash
ansible-vault encrypt_string 'secret_value' --name 'var_name'
```

## Architecture

### Module Structure

Each of the three modules follows the same layout:
```
<module>/
├── ansible.cfg           # Points inventory=inventory, vault_password_file=.vault_pass
├── ansible-navigator.yml # EE configuration for ansible-navigator
├── execution-environment.yml  # Container image definition (base: fedora:40)
├── inventory             # Static inventory with host groups
├── host_vars/            # Per-host variable files (gitignored — contain secrets)
├── roles/                # Ansible roles
└── *.yml                 # Playbooks
```

### network_infrastructure

Configures VPN, DNS, and proxy for all hosts.

| Playbook | Purpose | Target |
|---|---|---|
| `setup_network_play.yml` | WireGuard VPN | gateway, clients, servers, vpnserver |
| `setup_dns_play.yml` | DNSmasq DNS server | gateway (gtw01) |

Key roles: `wireguard`, `dnsmasq`, `dante` (SOCKS proxy).

Host groups: `vpnserver` (public IP), `gateway` (gtw01: 192.168.1.50), `server` (srv01-03), `armsrv` (arm01: 10.0.0.3), `virtualization` (Proxmox nodes), `mainsail` (3D printer).

### general_configuration

Configures the ARM server (arm01) with container runtime, reverse proxy, and UPS monitoring.

| Playbook | Purpose |
|---|---|
| `setup_containers_play.yml` | Podman + quadlet container units |
| `setup_nginx_play.yml` | Nginx reverse proxy + NUT (UPS) |
| `setup_firewall_play.yml` | UFW firewall rules |

Key roles: `container_runtime` (Podman/quadlet), `nginx`, `nut`.

### kubernates_infrastructure

Full Kubernetes cluster setup with Istio service mesh.

Single entry point: `playbook.yml` — runs 13 sequential plays:
1. Install Kubernetes + CRI-O on all nodes
2. Initialize master with Flannel CNI
3. Join workers via generated token
4. Label worker nodes
5. Install Istio service mesh
6. Install OperatorHub

Key roles: `kubernetes` (base install), `kube_master`, `kube_worker`.

Host groups: `master` (srv01: 10.0.0.2), `worker` (srv02/03: 10.0.0.3-4), `client` (localhost).

Kubeconfig is copied to `context/` (gitignored).

## Secrets & Sensitive Files

`.gitignore` excludes: `*.vault_pass`, `host_vars/`, `wireguard_keys/`, `context/`. These must be created locally before running playbooks. Host-specific variables live in `host_vars/<hostname>/main.yml` within each module.

## Execution Environments

Each module defines an `execution-environment.yml` for building a container image that includes the required Ansible collections and Python dependencies. The Kubernetes module additionally includes `kubernetes.core` and `fedora.linux_system_roles`.

Build an EE with:
```bash
ansible-builder build -t <tag> -f execution-environment.yml
```
