# VPN design (task 3), Project A, Team 3

Authors: Polish and Philipines team. Version: 2026-11-04.

## 1. Overview

WireGuard hub and spoke. The hub is the EC2 instance coil-vm in ap-southeast-2 (Sydney),
public address 54.66.81.25 (Elastic IP), UDP port 51820, VPN address 10.8.0.1.
Every member, both faculty members and the Uptime Kuma VM are peers.
Split tunnel: clients route only 10.8.0.0/24 through the VPN.
Nextcloud, SSH and the team dashboard are reachable only inside the VPN.

### Design decisions

| Decision | What we chose | Why |
| --- | --- | --- |
| Topology | Hub and spoke: one WireGuard server (hub) on the EC2 instance, every person and the Kuma VM is a spoke | Laptops sit behind home and campus routers (NAT) and cannot reach each other directly; all of them can reach one public server |
| Who talks to whom | Peers talk only to the server (10.8.0.1). Exception: VPN users may reach the Kuma status page, 10.8.0.20 port 3001 | Smallest possible attack surface; faculty still see the status page |
| Split tunnel | AllowedIPs = 10.8.0.0/24 on clients | Normal browsing stays on each person's own connection: faster, no extra cloud traffic cost |
| Port | UDP 51820 (WireGuard default) | Only this port is open on the internet; WireGuard does not answer unknown packets, so to a scanner it looks closed |
| Keys | One key pair plus one preshared key per peer, created on the server by scripts/add-peer.sh | Simple to hand out; the preshared key adds a second secret per peer |
| Keepalive | PersistentKeepalive = 25 on clients | Home routers forget idle UDP mappings; a small packet every 25 s keeps the tunnel open |
| Addresses | One fixed /32 per peer from this written plan | Logs, ufw rules, fail2ban bans and the dashboard can name every device |

Alternative considered: keys generated on each client (private key never leaves the device,
but every peer must first send its public key to an admin). We chose server-side keys for
simplicity and deliver each file privately.

## 2. Addressing plan

| Network or address | Use |
| --- | --- |
| 10.8.0.0/24 | VPN network |
| 10.8.0.1 | EC2 instance: WireGuard server, Nextcloud (HTTPS 443), SSH 22, dashboard |
| 10.8.0.2 - 10.8.0.9 | Team members (2 to 5 used) |
| 10.8.0.10 - 10.8.0.19 | Faculty (10 and 11 used) |
| 10.8.0.20 - 10.8.0.29 | Monitoring (20 = Uptime Kuma VM) |
| 10.8.0.30 - 10.8.0.39 | Spare and tests |
| 172.31.0.0/16 | AWS default VPC (private address of the instance) |
| 172.30.0.0/24 | Docker network inside the instance |
| 10.0.2.0/24 | VirtualBox NAT inside the Polish VM (no conflict with 10.8.0.0/24) |

## 3. Peers

| Peer name | Person or device | VPN address | Device | Delivered on | Removed |
| --- | --- | --- | --- | --- | --- |
<<<<<<< HEAD
| ph-member1 | PH 1 | 10.8.0.2 | Windows laptop | DATE | end of COIL |
| ph-member2 | PH 2 | 10.8.0.3 | Windows laptop | DATE | end of COIL |
| pl-member1 | PL 1 | 10.8.0.4 | Windows 11 laptop | DATE | end of COIL |
| pl-member2 | PL 2 | 10.8.0.5 | LAPTOP OS | DATE | end of COIL |
| fac-sacay | Ar-Jay R. Sacay, MIT | 10.8.0.10 | OS | DATE | end of COIL |
| fac-frankowski | Dr. Paweł Frankowski | 10.8.0.11 | OS | DATE | end of COIL |
=======
| ph-member1 | Mayo E. Nugas | 10.8.0.2 | Windows laptop | DATE | end of COIL |
| ph-member2 | Bonnel Jhon I. Catipay | 10.8.0.3 | Windows laptop | DATE | end of COIL |
| pl-member1 | Jędrzej Gąsiorowski | 10.8.0.4 | Windows 11 laptop | DATE | end of COIL |
| pl-member2 | PL NAME 2 | 10.8.0.5 | LAPTOP OS | DATE | end of COIL |
| fac-dorsu | Ar-Jay R. Sacay, MIT | 10.8.0.10 | OS | DATE | end of COIL |
| fac-mus | Dr. Paweł Frankowski | 10.8.0.11 | OS | DATE | end of COIL |
>>>>>>> 57d834ba07c6626777757fde2aed6aaff245ea71
| kuma | Uptime Kuma VM, Szczecin | 10.8.0.20 | Ubuntu 26.04 LTS VM (VirtualBox) | DATE | end of COIL |

## 4. Peer settings

Server (wg0): Address 10.8.0.1/24, ListenPort 51820. One [Peer] per row above with
PublicKey, PresharedKey and AllowedIPs = <address>/32.

Client: Address <address>/32, Endpoint 54.66.81.25:51820, AllowedIPs 10.8.0.0/24,
PersistentKeepalive 25. No DNS setting (services are used by IP address).

MTU: default (1420). If a network breaks large transfers, set MTU = 1280 on that client.

## 5. Key handling

- Keys are created on the server by scripts/add-peer.sh; client files are in
  /etc/wireguard/clients (root only, 700).
- Each file goes only to its owner, in a private message or university email,
  never to the group chat or Git (.gitignore blocks wireguard/*.conf).
- Lost or leaked file: remove the peer (scripts/remove-peer.sh) and add a new one.
- End of COIL: faculty peers removed first, then all peers.

## 6. Firewall rules (three layers)

### 6.1 AWS security group coil-sg (in front of the instance)

| Direction | Protocol and port | Source | Purpose |
| --- | --- | --- | --- |
| Inbound | UDP 51820 | 0.0.0.0/0 | WireGuard |
| Inbound | TCP 22 | ADMIN-IP/32 | TEMPORARY until SSH via VPN works; removed on DATE |
| Outbound | all | 0.0.0.0/0 | Updates, S3 backups (AWS default) |

### 6.2 ufw on the EC2 instance

| Rule | Purpose |
| --- | --- |
| default deny incoming, allow outgoing | Baseline |
| allow 51820/udp | WireGuard |
| allow in on wg0 to any port 22 proto tcp | SSH only through the VPN |
| allow in on wg0 to any port 443 proto tcp | Nextcloud and dashboard (documents intent) |
| route allow in on wg0 out on wg0 to 10.8.0.20 port 3001 proto tcp | VPN users to the Kuma status page |

Docker publishes HTTPS only on 10.8.0.1:443 (BIND_IP), because Docker's rules bypass ufw.

### 6.3 Uptime Kuma VM (Szczecin)

| Rule | Purpose |
| --- | --- |
| default deny incoming | Baseline |
| allow 22/tcp | SSH via the VirtualBox port forward (laptop only, 127.0.0.1:2223) |
| allow in on wg0 to any port 3001 proto tcp | Status page over the VPN |

Kuma is published only on 127.0.0.1:3001 and 10.8.0.20:3001. SSH is key-only, fail2ban is active.

## 7. Who can reach what

| From | To | Allowed? |
| --- | --- | --- |
| Internet | UDP 51820 on 54.66.81.25 | Yes (answers only known keys) |
| Internet | any TCP port on 54.66.81.25 | No (proved with Nmap, task 10) |
| Any VPN peer | 10.8.0.1:443 Nextcloud and /dashboard/ | Yes (Nextcloud login still needed) |
| Admins (sudo group) | 10.8.0.1:22 SSH with key | Yes |
| Non-admin peers | 10.8.0.1:22 | Port reachable, login refused (AllowGroups sudo) |
| Any VPN peer | 10.8.0.20:3001 status page | Yes |
| Kuma VM | 10.8.0.1 ping and 443 | Yes (monitoring) |
| Peer | another peer (except 10.8.0.20:3001) | No |

## 8. Tests

See task 10 (Nmap, docs/nmap/) and the VPN checks in the weekly reports.
