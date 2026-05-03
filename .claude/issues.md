# Problemi e Inconsistenze Rilevate

Analisi approfondita del 2026-04-30. Problemi classificati per gravità.
Ultima revisione: 2026-05-03 — aggiunti bug trovati durante setup dante-proxy LXC.

---

## CRITICI — ~~Possono causare errori di esecuzione~~ — CORRETTI ✓

### [C1] ~~Bug template Dante — variabile errata~~ — RISOLTO ✓
**File:** `network_infrastructure/roles/dante/templates/sockd.conf.j2`

Corretti 4 bug nel template:
1. Syntax error riga 5: `dante_port}}` (mancava `)`) → `dante_port) }}`
2. Riga 14: `{% for rule in client_pass_rules %}` → `{% for rule in dante.client_pass_rules %}`
3. Riga 19: `elif dante_client_deny_rules` → `elif dante_client_pass_rules` (variabile flat errata)
4. Riga 45: nel blocco `deny`, iterava su `dante.socks_pass_rules` invece di `dante.client_deny_rules`

---

### [C2] ~~Credenziali in chiaro in host_vars~~ — RISOLTO ✓
**File:** `general_configuration/host_vars/arm01/main.yml`

Le password NUT e la variabile `API_PASSWORD` del container sono ora referenziate tramite vault:
- `{{ vault_nut_admin_password }}`
- `{{ vault_nut_monitor_password }}`
- `{{ vault_nut_container_api_password }}`

Le variabili vault da definire sono documentate in `host_vars/arm01/vault.yml.example`.
Il `vault.yml` cifrato già esistente deve essere aggiornato con i nuovi nomi di variabile.

---

### [C3] ~~Firewall completamente disabilitato su nodi Kubernetes~~ — RISOLTO ✓
**File:** `kubernates_infrastructure/roles/kubernetes/tasks/main.yml`

Sostituita la disabilitazione di `firewalld` con configurazione delle porte specifiche tramite `ansible.posix.firewalld`. Le porte aperte sono configurabili via `kubernetes_firewall_ports` in `roles/kubernetes/defaults/main.yml`:
```yaml
kubernetes_firewall_ports:
  - 6443/tcp       # API server
  - 2379-2380/tcp  # etcd
  - 10250/tcp      # kubelet API
  - 10257/tcp      # kube-controller-manager
  - 10259/tcp      # kube-scheduler
  - 30000-32767/tcp  # NodePort services
  - 8472/udp       # Flannel VXLAN
```

---

## IMPORTANTI — Impattano la correttezza o la manutenibilità

### [I1] ~~Mancanza di idempotenza — `kubeadm init`~~ — RISOLTO ✓
**File:** `kubernates_infrastructure/roles/kube_master/tasks/main.yml`

Aggiunto `stat` check su `/etc/kubernetes/admin.conf` prima di `kubeadm init`. Se il file esiste, il cluster è già inizializzato e il task viene saltato.

`kubeadm join` nei worker già usava `args.creates: /etc/kubernetes/kubelet.conf` — era già idempotente.

---

### [I2] ~~URL Flannel hardcoded e non versionato~~ — RISOLTO ✓
**File:** `kubernates_infrastructure/roles/kube_master/tasks/main.yml` + `defaults/main.yml`

Aggiunta variabile `flannel_version: "v0.26.7"` in `defaults/main.yml`. L'URL usa ora la versione specifica:
```
https://github.com/flannel-io/flannel/releases/download/{{ flannel_version }}/kube-flannel.yml
```
Aggiornare `flannel_version` consultando la [matrice di compatibilità](https://github.com/flannel-io/flannel#compatibility-matrix).

---

### [I3] Inconsistenza naming variabili tra ruoli
Non risolto — è una convenzione che richiederebbe refactoring esteso dei ruoli. Documentato in `.claude/patterns.md`.

---

### [I4] Tag Ansible assenti
Non risolto — aggiungere tag ai task principali è consigliato per futuri sviluppi ma non causa errori.

---

### [I5] Handler `Restart kubelet` mancante nel ruolo `kubernetes`
Verificato: il ruolo `kubernetes` notifica solo `Restart crio` (presente in `handlers/main.yml`). Il `Restart kubelet` è notificato solo da `kube_master` e `kube_worker`, che hanno i propri handler. Non è un problema reale.

---

### [I6] ~~Base image EE su Fedora 40 (EOL)~~ — RISOLTO ✓
Tutti e tre i `execution-environment.yml` aggiornati da `fedora:40` a `fedora:42`.

---

## Bug aggiuntivi trovati durante i fix

### [B1] Path template CoreDNS — RISOLTO ✓
**File:** `kubernates_infrastructure/roles/kube_master/tasks/main.yml`

`src: templates/coredns-configmap.yml.j2` → `src: coredns-configmap.yml.j2`
Il modulo `ansible.builtin.template` cerca i file in `roles/<role>/templates/` automaticamente; aggiungere il prefisso `templates/` causa un errore di file non trovato.

---

## MINORI — Non corretti (basso impatto)

### [M1] Typo nel nome cartella
`kubernates_infrastructure` invece di `kubernetes_infrastructure`. Correggere richiederebbe aggiornare tutti i riferimenti (git history, playbook, docs) — rinvio.

### [M2] Commenti misti italiano/inglese
Convenzione stilistica, non funzionale.

### [M3] Versioni Kubernetes non pinned nei repo
`kubernetes-kubeadm` installato senza versione esatta. Basso rischio in ambienti home lab.

### [M4] `gather_facts: true` ridondante
Non causa errori, è il default di Ansible.

---

---

## Bug trovati durante setup dante-proxy LXC (2026-05-03)

### [B2] ~~Ruolo dante scriveva in `/etc/sockd.conf` invece di `/etc/danted.conf`~~ — RISOLTO ✓
**File:** `collections/.../roles/dante/tasks/main.yml`

Il servizio systemd Debian (`danted.service`) legge `/etc/danted.conf` per default. Il ruolo scriveva in `/etc/sockd.conf`, causando l'avvio con la configurazione di default del pacchetto (che aveva `internal: 0.0.0.0` — non supportato in Dante 1.4.2) e il crash con `no internal address given`.

Fix: cambiato `dest: /etc/sockd.conf` → `dest: /etc/danted.conf` nel task template.

---

### [B3] ~~Template Dante — una regola per blocco, non multiple `from` nello stesso blocco~~ — RISOLTO ✓
**File:** `collections/.../roles/dante/templates/sockd.conf.j2`

Dante non accetta più valori `from` in un singolo blocco `client pass {}`. Il template generava un unico blocco con tutte le subnet. Fix: template ora genera un blocco separato per ogni elemento della lista.

---

### [B4] ~~`internal: 0.0.0.0` non supportato in Dante 1.4.2~~ — RISOLTO ✓
**File:** `network_infrastructure/host_vars/dante-proxy/main.yml` + template

Dante 1.4.2 su Debian 12 non accetta `0.0.0.0` come indirizzo `internal`. Richiede il nome dell'interfaccia (es. `eth0`) o un IP concreto. Il default nel ruolo è stato lasciato a `eth0`.

---

### [B5] ~~`wireguard` role — apt install falliva per cache stale~~ — RISOLTO ✓
**File:** `collections/.../roles/wireguard/tasks/main.yml`

Su Debian 12 (LXC), apt install wireguard falliva con 404 perché la cache pacchetti era vuota. Fix: `update_cache: false` → `update_cache: true` per il task Debian.

---

## Checklist fix

- [x] **[C1]** Correggere variabile template Dante
- [x] **[C2]** Cifrare con vault le password in `host_vars/arm01/main.yml`
- [x] **[C3]** Configurare regole firewalld specifiche invece di disabilitare
- [x] **[I1]** Aggiungere idempotenza a `kubeadm init`
- [x] **[I2]** Pinnare versione Flannel tramite variabile
- [x] **[I6]** Aggiornare base image EE a Fedora 42
- [x] **[B1]** Fix path template CoreDNS
- [x] **[B2]** Ruolo dante: path config corretto a `/etc/danted.conf`
- [x] **[B3]** Template dante: un blocco per regola
- [x] **[B4]** `internal: eth0` invece di `0.0.0.0`
- [x] **[B5]** wireguard apt: `update_cache: true` su Debian
- [ ] **[I4]** Aggiungere tag Ansible ai task principali
- [ ] **[M1]** Rinominare cartella `kubernates_infrastructure`
