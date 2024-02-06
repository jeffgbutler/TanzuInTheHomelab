# Install Harbor on Ubuntu

## VM Setup

Create a VM with 8 vCPU, 16GB RAM, 160 GB Disk using Ubuntu Server (minimal)

Configure network as follows:

- IP Address: 192.168.128.133
- Netmask: 255.255.255.0
- Gateway: 192.168.128.1
- DNS: 192.168.128.1

```shell
sudo apt install open-vm-tools vim
```

## Install Docker

Follow the instructions here: https://docs.docker.com/engine/install/ubuntu/

Follow post install instructions here: https://docs.docker.com/engine/install/linux-postinstall/

## Install Harbor

`sudo mkdir -p /etc/docker/certs.d/harbor.tanzuathome.net`

Copy Harbor certificates as follows:

   - /etc/letsencrypt/live/tanzuathome.net/fullchain.pem ->  /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.cert
   - /etc/letsencrypt/live/tanzuathome.net/privkey.pem -> /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.key

Mac:

```shell
sudo cat /etc/letsencrypt/live/tanzuathome.net/fullchain.pem
```

Harbor: 

```shell
sudo vim /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.cert
```

Mac:

```shell
sudo cat /etc/letsencrypt/live/tanzuathome.net/privkey.pem
```

Harbor:

```shell
sudo vim /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.key
```

Then

- `sudo mkdir /harbor /data`
- `cd /harbor`
- `sudo curl -sLO https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz`
- `sudo tar xvf harbor-offline-installer-v2.10.0.tgz --strip-components=1`
- `sudo cp harbor.yml.tmpl harbor.yml`
- `sudo vim harbor.yml`

Set/Update the following:

- hostname: harbor.tanzuathome.net
- https:
  - certificate: /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.cert
  - private_key: /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.key

`sudo ./install.sh --with-trivy`

## Rotate Certificates on Harbor

1. Copy new certificates as follows:

   - /etc/letsencrypt/live/tanzuathome.net/fullchain.pem ->  /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.cert
   - /etc/letsencrypt/live/tanzuathome.net/privkey.pem -> /etc/docker/certs.d/harbor.tanzuathome.net/harbor.tanzuathome.net.key

1. `cd /harbor`
1. `docker compose down -v`
1. `./prepare --with-trivy`
1. `docker compose up -d`
