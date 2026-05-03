# Variabili Ansible — Reference Completo

Reference di tutte le variabili usate nei ruoli del progetto. Le variabili con default sono in `roles/<role>/defaults/main.yml`; quelle senza default **devono** essere definite in `host_vars/<hostname>/main.yml` (gitignored).

---

## network_infrastructure

### Ruolo: proxmox_lxc

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `proxmox_lxc_api_host` | _(obbligatorio)_ | string | IP/hostname del nodo Proxmox |
| `proxmox_lxc_api_user` | `"root@pam"` | string | Utente API Proxmox (sempre richiesto anche con token) |
| `proxmox_lxc_api_token_id` | _(obbligatorio)_ | string | Nome del token API (solo la parte dopo `!`, es. `test`) |
| `proxmox_lxc_api_token_secret` | _(obbligatorio, vault)_ | string | Segreto del token API |
| `proxmox_lxc_node` | `"pve"` | string | Nome del nodo Proxmox (verificare con `pvesh get /nodes`) |
| `proxmox_lxc_default_bridge` | `"vmbr0"` | string | Bridge di rete default |
| `proxmox_lxc_default_storage` | `"local-lvm"` | string | Storage default per il disco root |
| `proxmox_lxc_default_disk_size` | `"4"` | string | Dimensione disco root (GB) |
| `proxmox_lxc_nameserver` | `"1.1.1.1 8.8.8.8"` | string | DNS del container |
| `proxmox_lxc_containers` | `[]` | list | Lista container da creare |

**Struttura elemento `proxmox_lxc_containers`:**
```yaml
proxmox_lxc_containers:
  - container_name: "dante-proxy"     # Hostname del container
    vmid: 200                          # VMID Proxmox (univoco nel cluster)
    ip: "192.168.1.200/24"            # IP del container sull'interfaccia eth0
    gateway: "192.168.1.1"            # Gateway di default
    nameserver: "1.1.1.1 8.8.8.8"    # DNS (sovrascrive default)
    ostemplate: "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    groups: [lxc_containers]          # Gruppi inventory a cui aggiungere il container
```

**Note importanti:**
- Il ruolo usa `pct exec <vmid> -- bash -c 'systemctl is-active ssh'` delegato al nodo Proxmox per aspettare che SSH sia pronto (non `wait_for` che richiede raggiungibilità diretta)
- La connessione SSH al container usa un ProxyCommand: `ssh root@<node> pct exec <vmid> -- nc -q0 127.0.0.1 22`
- Il container viene aggiunto all'inventory in-memory via `add_host` dopo la creazione

---

### Ruolo: wireguard

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `wireguard_interface_name` | `"wg0"` | string | Nome interfaccia WireGuard |
| `wireguard_connection_name` | `"con-wg0"` | string | Nome connessione NetworkManager |
| `wireguard_keystore_directory` | `"./wireguard_keys"` | path | Directory locale dove salvare le chiavi generate |
| `wireguard_zone` | `"public"` | string | Zona FirewallD per WireGuard |
| `wireguard_ipv4_forwarding_needed` | `true` | bool | Abilita IP forwarding IPv4 via sysctl |
| `wireguard_ipv6_forwarding_needed` | `true` | bool | Abilita IP forwarding IPv6 via sysctl |
| `wireguard_port` | `51820` | int | Porta UDP di ascolto WireGuard |
| `wireguard_ipv4subnet` | `"10.0.0.0/24"` | cidr | Subnet IPv4 della VPN |
| `wireguard_ipv6subnet` | `"fd00:7::/64"` | cidr | Subnet IPv6 della VPN |
| `wireguard_clients` | `[]` | list | Lista peer WireGuard da configurare |
| `wireguard_post_up_commands` | `[]` | list | Comandi shell da eseguire al bring-up dell'interfaccia |
| `wireguard_post_down_commands` | `[]` | list | Comandi shell da eseguire al bring-down dell'interfaccia |
| `wireguard_update_keys` | `false` | bool | Se `true` rigenera le chiavi anche se esistono già |
| `wireguard_dns_server` | _(non impostato)_ | string | Server DNS da configurare nell'interfaccia (opzionale) |
| `wireguard_private_key` | _(runtime)_ | string | Chiave privata generata e registrata dal ruolo |
| `wireguard_key_pair_contents` | _(runtime)_ | dict | Output della generazione chiavi (`private_key`, `public_key`) |

**Struttura elemento `wireguard_clients`:**
```yaml
wireguard_clients:
  - public_key: "abc123=="          # Chiave pubblica del peer
    allowed_ips: "10.0.0.2/32"     # IP autorizzati per questo peer
    endpoint: "10.0.0.1:51820"     # Endpoint del peer (opzionale, per initiator)
    persistent_keepalive: 25        # Keepalive in secondi (opzionale)
```

---

### Ruolo: dnsmasq

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `dnsmasq.addresses` | _(obbligatorio)_ | list | Lista `{ name: "host.private", ip: "10.0.0.x" }` |
| `dnsmasq.cache_size` | _(obbligatorio)_ | int | Dimensione cache DNS |
| `dnsmasq.external_dns` | _(obbligatorio)_ | list | IP server DNS upstream (es. `["8.8.8.8"]`) |
| `dnsmasq.interfaces` | _(obbligatorio)_ | list | Interfacce di ascolto (es. `["wg0", "eth0"]`) |
| `dnsmasq.zone` | _(obbligatorio)_ | string | Zona FirewallD per la porta DNS |
| `hostname` | _(obbligatorio)_ | string | Hostname base (il ruolo imposta `<hostname>.private`) |

---

### Ruolo: dante

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `dante.log_output_file` | _(obbligatorio)_ | path | File di log Dante (es. `/var/log/danted.log`) |
| `dante.privileged_user` | _(obbligatorio)_ | string | Utente privilegiato del processo |
| `dante.unprivileged_user` | _(obbligatorio)_ | string | Utente non privilegiato del processo |
| `dante.interface_ip` | _(obbligatorio)_ | ip | IP di binding del server SOCKS |
| `dante.port` | _(obbligatorio)_ | int | Porta di ascolto SOCKS5 |
| `dante.interface` | _(obbligatorio)_ | string | Interfaccia esterna (es. `wg0`) |
| `dante.socks_method` | _(obbligatorio)_ | string | Metodo autenticazione SOCKS (es. `"username"`) |
| `dante.client_method` | _(obbligatorio)_ | string | Metodo autenticazione client (es. `"none"`) |
| `dante.client_pass_rules` | _(obbligatorio)_ | list | Regole `clientpass` |
| `dante.socks_pass_rules` | _(obbligatorio)_ | list | Regole `sockspass` |
| `dante.client_deny_rules` | _(obbligatorio)_ | list | Regole `clientdeny` |

---

## general_configuration

### Ruolo: container_runtime

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `container_runtime_containers` | `[]` | list | Lista container da gestire |
| `container_runtime_network_backend` | `"netavark"` | string | Backend rete Podman (`netavark` o `cni`) |
| `container_runtime_version` | _(runtime)_ | string | Versione Podman rilevata sull'host |
| `container_runtime_use_quadlet` | _(runtime)_ | bool | `true` se Podman >= 4.4.0 (usa Quadlet) |

**Struttura elemento `container_runtime_containers`:**
```yaml
container_runtime_containers:
  - container_name: "myapp"          # Nome del container (obbligatorio)
    image: "docker.io/nginx:latest"  # Immagine (obbligatorio)
    owner: "myuser"                  # Utente Linux proprietario (opzionale → root)
    build_image: false               # Costruisce immagine locale (opzionale)
    description: "My nginx"          # Descrizione unit systemd (opzionale)
    privileged: false                # Modalità privilegiata (opzionale)
    network: "host"                  # Modalità rete (opzionale)
    portmaps:                        # Port mapping (opzionale)
      - "8080:80"
    volumes:                         # Volumi (opzionale)
      - "/data/myapp:/data"
    devices:                         # Device pass-through (opzionale)
      - "/dev/ttyUSB0"
    environment:                     # Variabili ambiente (opzionale, usare vault per segreti)
      - "MY_VAR=value"
    restart: "always"                # Policy restart systemd (opzionale)
    wanted_by: "multi-user.target"  # Target systemd (opzionale)
    mode: "0755"                     # Permessi directory dati (opzionale)
    group: "root"                    # Gruppo directory dati (opzionale)
```

**Comportamento Quadlet vs Legacy:**
- Podman >= 4.4.0 → file `.container` in `/etc/containers/systemd/` (root) o `~/.config/containers/systemd/` (user)
- Podman < 4.4.0 → file `.service` in `/etc/systemd/system/` (root) o `~/.config/systemd/user/` (user)

---

### Ruolo: nginx

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `nginx_server_fqdn` | `"_"` | string | FQDN principale (catch-all se `_`) |
| `nginx_admin_email` | `"example@mail.com"` | string | Email per Certbot/Let's Encrypt |
| `nginx_http_port` | `80` | int | Porta HTTP |
| `nginx_https_port` | `443` | int | Porta HTTPS |
| `nginx_cloud_install` | `false` | bool | Se `false` salta l'installazione (per ambienti cloud) |
| `nginx_config_folder` | `"/etc/nginx"` | path | Directory configurazione Nginx |
| `nginx_config_folder_owner` | `"root"` | string | Proprietario directory config |
| `nginx_config_folder_group` | `"root"` | string | Gruppo directory config |
| `nginx_config_folder_mode` | `"0644"` | octal | Permessi directory config |
| `nginx_config.ssl_certificate` | _(obbligatorio)_ | path | Path certificato TLS |
| `nginx_config.ssl_certificate_key` | _(obbligatorio)_ | path | Path chiave privata TLS |
| `nginx_config.ssl_session_cache` | _(obbligatorio)_ | string | Configurazione cache sessioni SSL |
| `nginx_config.ssl_session_timeout` | _(obbligatorio)_ | string | Timeout sessioni SSL (es. `"10m"`) |
| `nginx_config.ssl_ciphers` | _(obbligatorio)_ | string | Cipher suite TLS |
| `nginx_config.ssl_prefer_server_ciphers` | _(obbligatorio)_ | string | `"on"` o `"off"` |
| `nginx_resources` | `[]` | list | Lista virtual host reverse proxy |

**Struttura elemento `nginx_resources`:**
```yaml
nginx_resources:
  - server_name: "myapp"
    server_fqdn: "myapp.example.com"
    proxy_fqdn: "localhost"          # Backend (se proxy semplice)
    server_port: 8080                # Porta backend
    upstreams:                       # Lista upstream (alternativa a proxy_fqdn)
      - name: "backend"
        servers: ["10.0.0.2:8080"]
```

---

### Ruolo: nut

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `nut_config_folder` | `"/etc/nut"` | path | Directory configurazione NUT |
| `nut_ups_list` | `[]` | list | Lista UPS da monitorare |
| `nut_conf_filemode` | `"0644"` | octal | Permessi file configurazione |
| `nut_owner` | `"nut"` | string | Utente proprietario file config |
| `nut_group` | `"nut"` | string | Gruppo proprietario file config |
| `nut_ssl_enabled` | `false` | bool | Abilita SSL per upsd |
| `nut_maxage` | `15` | int | Età massima dati UPS in secondi |
| `nut_maxconn` | `1024` | int | Connessioni massime upsd |
| `nut_force_ssl` | `0` | int | Forza SSL (`0`=no, `1`=sì) |
| `nut_mode` | `"standalone"` | string | Modalità NUT (`standalone`, `netserver`, `netclient`) |
| `nut_container` | `false` | bool | Se `true` usa path per container Alpine |
| `nut_listeners` | `["127.0.0.1"]` | list | IP di ascolto upsd |
| `nut_users` | _(obbligatorio)_ | list | Lista utenti upsd **(usare vault per le password)** |

**Struttura `nut_ups_list`:**
```yaml
nut_ups_list:
  - name: "myups"
    driver: "usbhid-ups"
    port: "auto"
    vendorid: "051d"       # ID vendor USB (hex)
    productid: "0002"      # ID prodotto USB (hex)
    subdriver: "apcsmart"
    desc: "APC UPS"        # opzionale
```

**Struttura `nut_users`:**
```yaml
nut_users:
  - name: "admin"
    password: "{{ vault_nut_admin_password }}"  # SEMPRE da vault
    role: "master"
    actions: "SET"
    instcmds: "ALL"
```

---

## kubernates_infrastructure

### Ruolo: kubernetes (installazione base — tutti i nodi)

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `hostname` | _(obbligatorio)_ | string | Hostname del nodo da impostare |

Versioni software installate (hardcoded nel ruolo):
- `cri-o >= 1.32.0`
- `cri-tools >= 1.32.0`
- `kubernetes-kubeadm` (ultima disponibile nel repo)

---

### Ruolo: kube_master

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `vpn_ip` | _(obbligatorio)_ | ip | IP WireGuard del master (es. `"10.0.0.2"`) |
| `vpn_interface` | _(obbligatorio)_ | string | Nome interfaccia WireGuard (es. `"wg0"`) |
| `pod_network_cidr` | `"10.244.0.0/16"` | cidr | CIDR rete pod Flannel |
| `dns_service_ip` | _(opzionale)_ | ip | IP del servizio CoreDNS |
| `kube_master_join_command` | _(runtime)_ | string | Comando `kubeadm join` generato per i worker |

---

### Ruolo: kube_worker

| Variabile | Default | Tipo | Descrizione |
|-----------|---------|------|-------------|
| `vpn_ip` | _(obbligatorio)_ | ip | IP WireGuard del nodo worker |
| `hostname` | _(obbligatorio)_ | string | Hostname del nodo worker |
| `kube_master_join_command` | _(da master via hostvars)_ | string | Letto da `hostvars[master_host]` |

**Esempio host_vars per srv01 (master):**
```yaml
hostname: srv01
vpn_ip: "10.0.0.2"
vpn_interface: "wg0"
pod_network_cidr: "10.244.0.0/16"
```

**Esempio host_vars per srv02/srv03 (worker):**
```yaml
hostname: srv02
vpn_ip: "10.0.0.3"
```
