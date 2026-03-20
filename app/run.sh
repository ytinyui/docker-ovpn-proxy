#!/usr/bin/env sh

# Simple script to launch OpenVPN and TinyProxy only when the VPN tunnel is available.
# It requires the host to provide a tun device; on mac use the `mac` profile.
# When the VPN disconnects, TinyProxy is terminated.

# ----------------------------------------------------------------------------
# Logging helper
# ----------------------------------------------------------------------------
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S")" "$*"
}

# ----------------------------------------------------------------------------
# Check for an OpenVPN configuration file
# ----------------------------------------------------------------------------
CONFIG_DIR="/data/ovpn"

if ! ls "$CONFIG_DIR"/*.ovpn >/dev/null 2>/dev/null; then
  log "ERROR:" "No OpenVPN configuration found. Exiting."
  exit 1
fi

OVPN_FILE=$(find "$CONFIG_DIR" -name "*.ovpn" | shuf | head -n 1)
log "INFO:" "Using OpenVPN config: $OVPN_FILE"

# ----------------------------------------------------------------------------
# Start OpenVPN
# ----------------------------------------------------------------------------
if [ -z "$OVPN_CREDENTIALS" ]; then
  log "INFO:" "Credentials not specified – using anonymous mode"
  openvpn --config "$OVPN_FILE" | tee /var/log/ovpn.log &
elif [ -f "$OVPN_CREDENTIALS" ]; then
  log "INFO:" "Using credentials file: $OVPN_CREDENTIALS"
  openvpn --config "$OVPN_FILE" --auth-user-pass "$OVPN_CREDENTIALS" | tee /var/log/ovpn.log &
else
  log "ERROR:" "Credentials file $OVPN_CREDENTIALS not found – exiting"
  exit 1
fi

OVPN_PID=$!

# ----------------------------------------------------------------------------
# Graceful cleanup on exit or signal
# ----------------------------------------------------------------------------
cleanup() {
  log "INFO:" "Cleanup: terminating child processes"
  kill "$OVPN_PID" 2>/dev/null || true
  if [ -n "$PROXY_PID" ]; then
    kill "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ----------------------------------------------------------------------------
# Helper to extract the IP address of tun0
# ----------------------------------------------------------------------------
get_tun_ip() {
  ip a | awk '/tun0/ {for(i=1;i<=NF;i++) if($i ~ /^inet/) {print $2; exit}}' | cut -d/ -f1
}

# ----------------------------------------------------------------------------
# Wait for the VPN to be ready
# ----------------------------------------------------------------------------
INIT_TIMEOUT=${INIT_TIMEOUT:-8}
for i in $(seq 0 $((INIT_TIMEOUT-1))); do
  if ip a | grep -q tun0; then
    break
  fi
  sleep 1
done

if ! ip a | grep -q tun0; then
  log "ERROR:" "VPN failed to connect – exiting"
  exit 1
fi

VPN_IP=$(get_tun_ip)
if [ -z "$VPN_IP" ]; then
  log "ERROR:" "Could not determine tun0 IP – exiting"
  exit 1
fi

log "INFO:" "VPN interface up – starting TinyProxy"

# Prepare TinyProxy config with dynamic bind address
cp /app/tinyproxy.conf /app/tinyproxy.conf.1
printf "\nBind %s\n" "$VPN_IP" >> /app/tinyproxy.conf.1

# Launch TinyProxy in background

log "INFO:" "Starting tinyproxy on $VPN_IP"
/usr/bin/tinyproxy -d -c /app/tinyproxy.conf.1 &
PROXY_PID=$!

# ----------------------------------------------------------------------------
# Monitor VPN connection – kill proxy on disconnect
# ----------------------------------------------------------------------------
while :; do
  if ! ip a | grep -q tun0; then
    log "INFO:" "VPN disconnected – terminating proxy"
    kill "$PROXY_PID" 2>/dev/null || true
    exit 0
  fi
  sleep 5
done
