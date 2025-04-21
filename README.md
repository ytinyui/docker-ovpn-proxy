# docker-ovpn-proxy

An HTTP proxy that goes through OpenVPN, inside a Docker container.

## Setup

### OpenVPN Config

Place one OpenVPN config file in the directory `data/ovpn/`.
If there are multiple config files, one will be chosen randomly.

### Credentials (optional)

Create `data/ovpn/credentials` in the format

```text
username
password
```

Uncomment the line with `OVPN_CREDENTIALS=/data/ovpn/credentials`.

## Usage

### Docker Compose

Run the following command:

```sh
docker compose up -d
```

### Testing

The two commands below should give different results.

```sh
curl ip.me # host IP address
curl ip.me --proxy localhost:8888 # VPN IP address
```
