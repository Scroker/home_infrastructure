# General Configuration

Questo modulo configura i servizi applicativi sull'host `arm01`: container Podman, reverse proxy Nginx, monitoraggio UPS con NUT e firewall UFW.

## Prerequisiti

- File `.vault_pass` presente nella directory `general_configuration/`
- Directory `host_vars/arm01/main.yml` creata (non versionata)
- `arm01` raggiungibile via SSH

## Playbook

### setup_containers_play.yml — Container Podman

Installa e configura il runtime container Podman su `arm01` con supporto Quadlet per la gestione dei servizi tramite systemd.

```bash
cd general_configuration
ansible-playbook setup_containers_play.yml
```

**Cosa fa il ruolo `container_runtime`:**
1. Installa Podman
2. Configura lingering systemd per utenti non-root (per container in autostart)
3. Crea volumi e directory per i dati dei container
4. Costruisce immagini da Dockerfile se presenti
5. Genera unit file systemd tramite Quadlet (o unit tradizionali come fallback)
6. Abilita e avvia i servizi container

### setup_nginx_play.yml — Nginx e NUT

Configura il reverse proxy Nginx e il monitoraggio UPS tramite NUT.

```bash
cd general_configuration
ansible-playbook setup_nginx_play.yml
```

**Ruolo `nginx`:**
1. Installa Nginx e Certbot per TLS
2. Applica template di configurazione
3. Avvia e abilita il servizio
4. Configura le regole firewall per HTTP/HTTPS

**Ruolo `nut`:**
1. Installa NUT (Network UPS Tools)
2. Configura tramite template: `nut.conf`, `ups.conf`, `upsd.conf`, `upsmon.conf`, `upssched.conf`
3. Configura regole udev per i permessi sul dispositivo UPS
4. Avvia e abilita i servizi NUT

### setup_firewall_play.yml — Firewall UFW

Configura il firewall UFW su `arm01`.

```bash
cd general_configuration
ansible-playbook setup_firewall_play.yml
```

**Porte aperte:**

| Porta | Protocollo | Servizio |
|-------|-----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 3493 | TCP | NUT upsd |
| 5000 | TCP | Applicazione custom |

La policy di default è: **incoming deny**, **outgoing allow**.

## Ordine di esecuzione consigliato

Se si configura `arm01` da zero, eseguire i playbook in quest'ordine:

```bash
cd general_configuration
ansible-playbook setup_firewall_play.yml
ansible-playbook setup_containers_play.yml
ansible-playbook setup_nginx_play.yml
```

## Ruoli

### container_runtime

Gestisce l'intero ciclo di vita dei container: dalla build dell'immagine all'avvio del servizio systemd. Usa Quadlet quando disponibile (Podman >= 4.4), altrimenti genera unit file systemd tradizionali per entrambi gli utenti root e non-root.

### nginx

Usa template Jinja2 per la configurazione dei virtual host. Il certificato TLS è gestito tramite Certbot.

### nut

Configura NUT in modalità standalone. I cinque file di configurazione principali (`nut.conf`, `ups.conf`, `upsd.conf`, `upsmon.conf`, `upssched.conf`) sono tutti generati da template e personalizzati tramite variabili in `host_vars/arm01/`.
