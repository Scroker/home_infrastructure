# Pattern, Convenzioni e Dipendenze

## Pattern ricorrenti nel codice

### 1. Rilevamento distro e package manager

Tutti i ruoli che installano pacchetti seguono questo pattern:

```yaml
- name: Install package (RedHat)
  ansible.builtin.dnf:
    name: "{{ package }}"
    state: present
  when: ansible_facts['os_family'] == "RedHat"

- name: Install package (Debian)
  ansible.builtin.apt:
    name: "{{ package }}"
    state: present
  when: ansible_facts['os_family'] == "Debian"
```

Per Fedora CoreOS si usa `rpm-ostree` invece di `dnf` — richiede reboot del nodo.

---

### 2. Rilevamento gestore di rete (ruolo wireguard)

Il ruolo wireguard rileva automaticamente il gestore di rete nell'ordine:
1. **Netplan** → genera `/etc/netplan/*.yaml`
2. **NetworkManager** → usa `community.general.nmcli`
3. **wg-quick** → genera `/etc/wireguard/wg0.conf` (fallback)

Ogni branch scrive la configurazione in modo idiomatico per il gestore rilevato.

---

### 3. Quadlet vs unit systemd legacy (ruolo container_runtime)

```yaml
- name: Rileva versione Podman
  ansible.builtin.command: podman --version
  register: container_runtime_version

- name: Imposta uso Quadlet
  ansible.builtin.set_fact:
    container_runtime_use_quadlet: >-
      {{ container_runtime_version.stdout | regex_search('\\d+\\.\\d+') is version('4.4', '>=') }}
```

- **Quadlet (>= 4.4.0):** file `.container` → `/etc/containers/systemd/` (root) o `~/.config/containers/systemd/` (user)
- **Legacy (< 4.4.0):** file `.service` → `/etc/systemd/system/` (root) o `~/.config/systemd/user/` (user)

Per user non-root il ruolo abilita il **lingering** via `loginctl enable-linger`.

---

### 4. Comunicazione master→worker in Kubernetes

Il join command viene registrato sul master e letto dai worker tramite `hostvars`:

```yaml
# Sul master (kube_master)
- name: Ottieni join command
  ansible.builtin.command: kubeadm token create --print-join-command
  register: kube_master_join_command

# Sul worker (kube_worker)
- name: Unisciti al cluster
  ansible.builtin.command: "{{ hostvars[groups['master'][0]]['kube_master_join_command'].stdout }}"
```

Il kubeconfig viene copiato dal master al client con `slurp` + `delegate_to`.

---

### 5. Template Jinja2 per configurazioni

Ogni ruolo usa template Jinja2. Pattern comune:

```yaml
- name: Copia configurazione
  ansible.builtin.template:
    src: "config.conf.j2"
    dest: "/etc/service/config.conf"
    owner: "{{ service_owner }}"
    group: "{{ service_group }}"
    mode: "{{ service_filemode }}"
  notify: Restart service
```

I template usano variabili con default definiti in `defaults/main.yml` per rendere il ruolo riusabile.

---

### 6. Flannel forzato sull'interfaccia WireGuard

Il ruolo `kube_master` patcha il DaemonSet Flannel per usare l'interfaccia WireGuard come `iface`. Questo garantisce che il traffico pod-to-pod tra nodi viaggi sempre cifrato nella VPN:

```yaml
- name: Patcha Flannel per usare interfaccia WireGuard
  kubernetes.core.k8s_json_patch:
    kind: DaemonSet
    namespace: kube-flannel
    name: kube-flannel-ds
    patch:
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: "--iface={{ vpn_interface }}"
```

---

## Collections Ansible utilizzate

| Collection | Moduli usati | Modulo |
|------------|-------------|--------|
| `ansible.builtin` | template, copy, file, service, command, shell, lineinfile, blockinfile, sysctl, modprobe... | Core Ansible |
| `ansible.posix` | `firewalld`, `sysctl` | network_infra, general_config |
| `community.proxmox` | `proxmox` (LXC creation) | proxmox_lxc |
| `community.general` | `nmcli`, `ini_file`, `modprobe` | wireguard |
| `community.crypto` | Gestione certificati | network_infra |
| `containers.podman` | Gestione container Podman | general_config |
| `kubernetes.core` | `k8s`, `k8s_json_patch`, `helm` | kubernetes_infra |
| `fedora.linux_system_roles` | `timesync` | kubernetes_infra |

---

## Versioni software specificate

| Software | Versione | Dove |
|----------|----------|------|
| CRI-O | `>= 1.32.0` | `kubernates_infrastructure/roles/kubernetes` |
| cri-tools | `>= 1.32.0` | `kubernates_infrastructure/roles/kubernetes` |
| kubeadm/kubelet/kubectl | latest nel repo | `kubernates_infrastructure/roles/kubernetes` |
| Flannel | latest da GitHub | `kubernates_infrastructure/roles/kube_master` |
| Istio | latest via Helm | `kubernates_infrastructure/tasks/install_istio.yml` |
| Podman | Versione rilevata runtime | `general_configuration/roles/container_runtime` |
| Base image EE | `quay.io/fedora/fedora:40` | Tutti i moduli |
| NUT (Alpine) | `docker.io/alpine:latest` | `general_configuration` (container) |

> **Nota:** Flannel e Istio vengono installati all'ultima versione disponibile. Per ambienti di produzione considerare di fissare le versioni.

---

## Pattern 7: Provisioning LXC Proxmox via API token

Il ruolo `proxmox_lxc` usa il modulo `community.proxmox.proxmox` con autenticazione via token API:

```yaml
- name: Crea LXC
  community.proxmox.proxmox:
    api_host: "{{ proxmox_lxc_api_host }}"
    api_user: "{{ proxmox_lxc_api_user }}"        # Sempre richiesto, anche con token
    api_token_id: "{{ proxmox_lxc_api_token_id }}" # Solo il nome (es. "test"), NON "root@pam!test"
    api_token_secret: "{{ proxmox_lxc_api_token_secret }}"
    node: "{{ proxmox_lxc_node }}"
    ...
```

**Attendere SSH con pct exec (non wait_for):**
Poiché il container non è raggiungibile direttamente dalla macchina di controllo, si usa `pct exec` delegato al nodo Proxmox:

```yaml
- name: Attendi SSH
  ansible.builtin.command:
    cmd: "pct exec {{ item.vmid }} -- bash -c 'systemctl is-active ssh'"
  delegate_to: "{{ inventory_hostname }}"  # Il nodo Proxmox
  until: result.rc == 0
  retries: 24
  delay: 5
```

**ProxyCommand per SSH al container:**
```yaml
ansible_ssh_common_args: >-
  -o StrictHostKeyChecking=no
  -o ProxyCommand="ssh -o StrictHostKeyChecking=no root@{{ ansible_host }} pct exec {{ vmid }} -- nc -q0 127.0.0.1 22 2>/dev/null"
```

---

## Dipendenze e ordine di esecuzione

```
network_infrastructure   (prerequisito per tutto)
  ├─ setup_network_play.yml    → WireGuard su tutti gli host
  ├─ setup_dns_play.yml        → DNS su gtw01
  └─ setup_proxy_play.yml      → LXC Dante proxy su Proxmox
       ├─ Play 1: proxynodes   → Crea e avvia container LXC
       ├─ Play 2: lxc_containers → WireGuard nel container (genera chiavi)
       ├─ Play 3: vpnserver    → WireGuard sul VPN server (aggiunge peer)
       └─ Play 4: lxc_containers → Installa e configura Dante
       IMPORTANTE: Play 2 deve precedere Play 3 — le chiavi vengono generate sul
       container e lette dal server. Invertire l'ordine causa KeyError.

general_configuration    (richiede VPN attiva per arm01)
  ├─ setup_firewall_play.yml   → UFW su arm01 (eseguire PRIMA)
  ├─ setup_containers_play.yml → Podman su arm01
  └─ setup_nginx_play.yml      → Nginx + NUT su arm01

kubernates_infrastructure  (richiede VPN attiva tra srv01/02/03)
  └─ playbook.yml              → Esecuzione sequenziale completa
```

**Dipendenze runtime interne a kubernates_infrastructure:**
- `kube_master` deve completare prima di `kube_worker` (genera il join command)
- Il kubeconfig viene aggiornato sul client dopo ogni fase significativa

---

## Convenzioni di naming

| Elemento | Convenzione | Esempio |
|----------|------------|---------|
| Variabili ruolo | `<ruolo>_<variabile>` | `wireguard_port`, `nginx_http_port` |
| Variabili strutturate | dizionario con nome ruolo | `dnsmasq.cache_size`, `dante.port` |
| Template | `<config_file>.j2` | `sockd.conf.j2`, `dnsmasq.conf.j2` |
| Host vars | `host_vars/<hostname>/main.yml` | `host_vars/srv01/main.yml` |
| Playbook | `setup_<servizio>_play.yml` | `setup_network_play.yml` |

**Inconsistenza:** Il ruolo `wireguard` usa prefix `wireguard_*` (flat), mentre `dnsmasq` e `dante` usano un dizionario con chiave radice (`dnsmasq.*`, `dante.*`). I ruoli di `general_configuration` tornano al prefix flat (`nginx_*`, `nut_*`, `container_runtime_*`).

---

## Gestione segreti

I segreti vanno **sempre** in `host_vars/<hostname>/vault.yml` cifrato con ansible-vault:

```bash
# Crea vault file
ansible-vault create host_vars/srv01/vault.yml

# Cifra variabile inline
ansible-vault encrypt_string 'valore' --name 'vault_mia_password'
```

Il file `.vault_pass` (gitignored) contiene la password del vault ed è letto automaticamente da `ansible.cfg`:
```ini
vault_password_file = .vault_pass
```

**File sensibili gitignored in ogni modulo:** `host_vars/`, `*.vault_pass`, `wireguard_keys/`, `context/`
