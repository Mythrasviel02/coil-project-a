# Coil Project A: Campus-to-Campus File

## Overview
This repository contains the configuration files, documentation, and evidence for **Project A**, a collaborative cross-continental project connecting students and faculty between DOrSU (Philippines) and the Maritime University of Szczecin (Poland). 

The primary goal is to establish a secure, shared file-sharing environment by hosting a private Nextcloud service on a cloud Virtual Machine (VM). Access is strictly restricted via a WireGuard VPN, backed by automated cloud storage backups, team dashboards, and robust uptime monitoring.

---

## Architecture & Core Requirements
* **Nextcloud & Stack:** Deployed via Docker Compose, utilizing Nextcloud, MariaDB, and Nginx (HTTPS).
* **Secure Access:** Powered by a WireGuard VPN server; no services are exposed directly to the public internet
* **Folder Structure:** Dedicated group folders configured for Mati (Philippines), Szczecin (Poland), and a shared joint folder.
* **Backups:** Automated nightly restic backups sent securely to cloud storage
* **Monitoring:** Uptime Kuma monitoring instance providing status pages and team chat alerts
