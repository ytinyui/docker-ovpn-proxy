# docker-ovpn-proxy

An HTTP proxy that goes through OpenVPN, inside a Docker container.
All traffic is forced through the VPN tunnel via an iptables-based kill switch.

## Setup

### OpenVPN Config

Place one or more `.ovpn` config files in the directory `data/ovpn/`.
If there are multiple configs, one will be chosen randomly at startup.

### Credentials (optional)

Create `data/ovpn/credentials` in the format

```text
username
password
```

In `compose.yaml`, uncomment the line with `OVPN_CREDENTIALS=/data/ovpn/credentials`.

## Usage

### Docker Compose

Run the following command:

```sh
# Linux
docker compose up -d
# MacOS
docker compose --profile mac up -d
```

### Testing

The two commands below should give different results.

```sh
curl ip.me # host IP address
curl ip.me --proxy localhost:8888 # VPN IP address
```
