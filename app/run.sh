#!/usr/bin/env sh

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S")" "$*"
}

# check ovpn config
if ! ls "/data/ovpn/"*.ovpn >/dev/null 2>/dev/null; then
  log "ERROR:" "No OpenVPN config found. Exiting."
  exit 1
fi

OVPN_FILE=$(find /data/ovpn -name "*.ovpn" | shuf | head -n 1)
echo "Using ${OVPN_FILE}"
if [ -z "${OVPN_CREDENTIALS}" ]; then
  log "INFO:" "Credentials not specified"
  openvpn --config "${OVPN_FILE}" | tee /var/log/ovpn.log &
elif [ -f "${OVPN_CREDENTIALS}" ]; then
  openvpn --config "${OVPN_FILE}" --auth-user-pass "${OVPN_CREDENTIALS}" | tee /var/log/ovpn.log &
else
  log "ERROR:" "${OVPN_CREDENTIALS} does not exist, Exiting."
  exit 1
fi

i=0
while [ "${i}" -lt "${INIT_TIMEOUT:=8}" ]; do
  if ip a | grep tun0 >/dev/null; then
    ip=$(ip a | grep tun0 | tail -n 1 | awk '{ print $2 }' | sed -E 's/\/[0-9]+$//')
    cp /app/tinyproxy.conf /app/tinyproxy.conf.1
    echo "Bind ${ip}" >>/app/tinyproxy.conf.1
    log "INFO:" "Starting tinyproxy"
    tinyproxy -d -c /app/tinyproxy.conf.1
  fi
  sleep 1
  i=$((i + 1))
done

log "ERROR:" "VPN failed to connect"
exit
