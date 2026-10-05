#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

[[ $EUID -eq 0 ]] || {
    echo "ERROR: run as root" >&2
    exit 1
}

required_commands=(
    podman
    tc
    ip
    nsenter
    flock
    awk
    grep
    sed
    cut
    mktemp
)

for cmd in "${required_commands[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: missing command: $cmd" >&2
        exit 1
    }
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

install -d -m 0755 /usr/local/bin
install -d -m 0755 /var/lib/netdrop/state
install -d -m 0755 /run/lock

install -m 0755 \
    "$SCRIPT_DIR/netdrop" \
    /usr/local/bin/netdrop

install -m 0644 \
    "$SCRIPT_DIR/netdrop.service" \
    /etc/systemd/system/netdrop.service

if [[ ! -f /etc/default/netdrop ]]; then
    install -m 0644 /dev/null /etc/default/netdrop

    cat > /etc/default/netdrop <<'EOF'
# Network interface inside the container.
CONTAINER_IF=eth0

# netdrop daemon verification interval.
INTERVAL=60
EOF
fi

if [[ ! -f /etc/netdrop.list ]]; then
    install -m 0644 /dev/null /etc/netdrop.list
fi

systemctl daemon-reload
systemctl enable netdrop.service
systemctl restart netdrop.service

echo
echo "netdrop installed."
echo
echo "Commands:"
echo "  netdrop add <container>"
echo "  netdrop remove <container>"
echo "  netdrop list"
echo "  netdrop check"
echo "  netdrop show <container>"
echo
echo "Service:"
echo "  systemctl status netdrop"
