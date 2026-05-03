# Architettura dell'Infrastruttura

## Panoramica

Il laboratorio domestico si compone di tre strati sovrapposti: una rete fisica LAN, una rete VPN overlay costruita con WireGuard, e un cluster Kubernetes che usa la VPN come rete di trasporto per il piano di controllo.

```mermaid
graph TD
    Internet((Internet))

    subgraph VPN["WireGuard VPN — 10.0.0.0/24"]
        vpnsrv01["vpnsrv01\nVPS pubblica · endpoint remoto"]

        subgraph LAN["LAN — 192.168.1.0/24"]
            gtw01["gtw01\nGateway · DNS"]
            arm01["arm01\nContainer · Nginx · NUT"]
            mns01["mns01\nMainsail · stampante 3D"]

            subgraph Proxmox["Cluster Proxmox"]
                node01["node01"]
                node02["node02"]
                danteproxy["dante-proxy LXC\nProxy SOCKS5 :1080"]
            end

            subgraph K8s["Cluster Kubernetes"]
                srv01["srv01\nmaster"]
                srv02["srv02\nworker"]
                srv03["srv03\nworker"]
            end
        end
    end

    Internet -->|HTTPS| vpnsrv01
    vpnsrv01 <-->|tunnel WireGuard| gtw01
    vpnsrv01 <-->|tunnel WireGuard| arm01
    vpnsrv01 <-->|tunnel WireGuard| srv01
    vpnsrv01 <-->|tunnel WireGuard| danteproxy
    gtw01 <-->|LAN| arm01
    gtw01 <-->|LAN| mns01
    gtw01 <-->|DNS| srv01
    srv01 <-->|VPN| srv02
    srv01 <-->|VPN| srv03
    node01 -.-|"pct exec"| danteproxy
    node01 & node02 -->|"VM Fedora CoreOS"| srv01 & srv02 & srv03
```

## Reti

| Rete | Scopo |
|------|-------|
| LAN | Rete fisica locale |
| WireGuard VPN (`10.0.0.0/24`) | Overlay cifrato tra tutti gli host |

Il cluster Kubernetes usa gli indirizzi VPN per la comunicazione interna tra nodi, disaccoppiando il cluster dalla topologia fisica della LAN.

## Host

| Host | Ruolo |
|------|-------|
| vpnsrv01 | VPN server pubblico (endpoint remoto) |
| gtw01 | Gateway, DNS (dnsmasq), VPN hub |
| arm01 | Server ARM, container Podman, nginx, NUT |
| srv01 | Kubernetes master |
| srv02 | Kubernetes worker |
| srv03 | Kubernetes worker |
| node01 | Nodo Proxmox |
| node02 | Nodo Proxmox |
| dante-proxy | LXC su node01 — proxy SOCKS5 Dante, VPN + LAN |
| mns01 | Controller stampante 3D (Mainsail) |

## Stack tecnologico

| Livello | Tecnologia |
|---------|-----------|
| Virtualizzazione | Proxmox VE |
| Sistema operativo VM | Fedora CoreOS |
| VPN | WireGuard |
| DNS | dnsmasq |
| Proxy SOCKS | Dante (LXC su Proxmox) |
| Container | Podman + Quadlet |
| Reverse proxy | Nginx + Certbot |
| Monitoraggio UPS | NUT (Network UPS Tools) |
| Firewall (arm01) | UFW |
| Orchestrazione | Kubernetes (kubeadm) |
| Container runtime K8s | CRI-O |
| CNI | Flannel |
| Service mesh | Istio (via Helm) |
| Operator framework | OperatorHub |

## Moduli Ansible

Il repository è diviso in tre moduli indipendenti, ciascuno con il proprio `ansible.cfg` e `inventory`. Possono essere eseguiti in qualsiasi ordine, ma la sequenza consigliata è:

```mermaid
flowchart TD
    A["1 · network_infrastructure\nVPN WireGuard · DNS · Proxy SOCKS5"]
    B["2 · general_configuration\nContainer · Nginx · NUT · Firewall"]
    C["3 · kubernates_infrastructure\nKubernetes · Istio · OperatorHub"]

    A --> B --> C
```

Per i dettagli di ogni modulo consultare la documentazione specifica:
- [Network Infrastructure](network_infrastructure.md)
- [General Configuration](general_configuration.md)
- [Kubernetes Infrastructure](kubernetes_infrastructure.md)
