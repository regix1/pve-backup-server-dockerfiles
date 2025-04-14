# Proxmox Backup Server in a Container
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/regix1/pve-backup-server-dockerfiles)](https://github.com/regix1/pve-backup-server-dockerfiles/releases)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/regix1/pve-backup-server-dockerfiles?include_prereleases)](https://github.com/regix1/pve-backup-server-dockerfiles/releases)
[![Docker Image CI](https://github.com/regix1/pve-backup-server-dockerfiles/actions/workflows/docker-image.yml/badge.svg)](https://github.com/regix1/pve-backup-server-dockerfiles/actions/workflows/docker-image.yml)

This is an unofficial compilation of Proxmox Backup Server to run it in a container for AMD64 architecture.

Running in a container might result in some functions not working properly. Feel free to create an issue to debug those.

## Common problems
- Some people see authentication failure using admin@pbs: Ensure that `/run` is mounted to tmpfs which is requirement of 2.1.x
- Some Synology devices use a really old kernel (3.1), for such the ayufan#15 is needed, and image needs to be manually recompiled.

## Pre-built images
For starting quickly all images are precompiled and hosted on GitHub Container Registry:

```
docker pull ghcr.io/regix1/proxmox-backup-server:latest
```

You can find all available image tags at: [https://github.com/regix1/pve-backup-server-dockerfiles/pkgs/container/proxmox-backup-server](https://github.com/regix1/pve-backup-server-dockerfiles/pkgs/container/proxmox-backup-server)

## Run
```
docker-compose up -d
```

Then login to https://<ip>:8007/ with admin / pbspbs. After that change a password.

## Features
The core features should work, but there are ones do not work due to container architecture:

- ZFS: it is not installed in a container
- Shell: since the PVE (not PAM) authentication is being used, and since the shell access does not make sense in an ephemeral container environment
- PAM authentication: since containers are by definition ephemeral and no /etc/ configs are being persisted

## Changelog
See [Releases](https://github.com/yourusername/proxmox-backup-server-container/releases).

## Configure
### 1. Add to Proxmox VE
Since it runs in a container, it is by default self-signed. Follow the tutorial: https://pbs.proxmox.com/docs/pve-integration.html.

You might need to read a PBS fingerprint:

```
docker-compose exec server proxmox-backup-manager cert info | grep Fingerprint
```

### 2. Add a new directory to store data
Create a new file (or merge with existing): `docker-compose.override.yml`:

```yaml
version: '2.1'

services:
  pbs:
    volumes:
      - backups:/backups

volumes:
  backups:
    driver: local
    driver_opts:
      type: ''
      o: bind
      device: /srv/dev-disk-by-label-backups
```

Then, add a new datastore in a PBS: https://<IP>:8007/.

### 3. Configure TZ (optional)
If you are running in Docker it might be advised to configure timezone.

Create a new file (or merge with existing): `docker-compose.override.yml`:

```yaml
version: '2.1'

services:
  pbs:
    environment:
      TZ: Europe/Warsaw
```

### 4. Allow smartctl access
To be able to view SMART parameters via UI you need to expose drives and give container a special capability.

Create a new file (or merge with existing): `docker-compose.override.yml`:

```yaml
version: '2.1'

services:
  pbs:
    devices:
      - /dev/sda
      - /dev/sdb
    cap_add:
      - SYS_RAWIO
```

### 5. Persist config, graphs, and logs (optional, but advised)
Create a new file (or merge with existing): `docker-compose.override.yml`:

```yaml
version: '2.1'

volumes:
  pbs_etc:
    driver: local
    driver_opts:
      type: ''
      o: bind
      device: /srv/pbs/etc
  pbs_logs:
    driver: local
    driver_opts:
      type: ''
      o: bind
      device: /srv/pbs/logs
  pbs_lib:
    driver: local
    driver_opts:
      type: ''
      o: bind
      device: /srv/pbs/lib
```

### 6. Custom Script options:
Run different setup script options:

```yaml
version: '2.1'

services:
  pbs:
    environment:
      - PBS_SOURCES=yes
      - PBS_ENTERPRISE=yes
      - PBS_NO_SUBSCRIPTION=yes
      - PBS_TEST=no
      - DISABLE_SUBSCRIPTION_NAG=yes
      - UPDATE_PBS=yes
      - REBOOT_PBS=no
```

### 7. Build Command from root directory:
```
docker build -t proxmox-backup-server --build-arg VERSION=v3.3.2 -f versions/v3.3.2/Dockerfile .
```

## Install on bare-metal host
Docker is convenient, but in some cases it might be simply better to install natively. Since the packages are built against Debian Buster your system needs to run soon to be stable distribution.

You can copy compiled *.deb (it will automatically pick amd64 or arm64v8 based on your distribution) from the container and install:

```
cd /tmp
docker run --rm ghcr.io/regix1/proxmox-backup-server:latest tar c /src/ | tar x
apt install $PWD/src/*.deb
```

## Recompile latest version or master
Refer to [PROCESS.md](PROCESS.md).

## Build on your own
Refer to [PROCESS.md](PROCESS.md).

## Author
This is just built by [Your Name], [Year] from the sources found on http://git.proxmox.com/.
