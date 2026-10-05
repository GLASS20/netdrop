#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly INSTALL_DIR="/usr/local/bin"
readonly STATE_DIR="/var/lib/netdrop/state"
readonly LOCK_DIR="/run/lock"

require_root() {
    [[ "${EUID}" -eq 0 ]] || {
        echo "ERROR: run as root" >&2
        exit 1
    }
}

require_command() {
    local cmd="$1"

    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: missing command: $cmd" >&2
        exit 1
    }
}

require_root

required_commands=(
    podman
    nft
    tc
    ip
    nsenter
    flock
    awk
    grep
    sed
    cut
    mktemp
    install
    systemctl
)

for cmd in "${required_commands[@]}"; do
    require_command "$cmd"
done

if ! podman info >/dev/null 2>&1; then
    echo "ERROR: Podman is not available through the current root context" >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

install -d -m 0755 "$INSTALL_DIR"
install -d -m 0755 "$STATE_DIR"
install -d -m 0755 "$LOCK_DIR"

install -m 0755 \
    "$SCRIPT_DIR/netdrop" \
    "$INSTALL_DIR/netdrop"

install -m 0644 \
    "$SCRIPT_DIR/netdrop.service" \
    /etc/systemd/system/netdrop.service

if [[ ! -f /etc/default/netdrop ]]; then
    cat > /etc/default/netdrop <<'EOF'
# Interface inside the Podman container.
CONTAINER_IF=eth0

# netdrop daemon verification interval, seconds.
INTERVAL=60
EOF

    chmod 0644 /etc/default/netdrop
fi

if [[ ! -f /etc/netdrop.list ]]; then
    : > /etc/netdrop.list
    chmod 0644 /etc/netdrop.list
fi

chmod 0755 "$INSTALL_DIR/netdrop"
chmod 0755 "$STATE_DIR"

systemctl daemon-reload
systemctl enable netdrop.service
systemctl restart netdrop.service

echo
echo "netdrop installed successfully."
echo
echo "Binary:"
echo "  /usr/local/bin/netdrop"
echo
echo "Configuration:"
echo "  /etc/default/netdrop"
echo "  /etc/netdrop.list"
echo
echo "State:"
echo "  /var/lib/netdrop/state/"
echo
echo "Service:"
echo "  systemctl status netdrop.service"
echo
echo "Commands:"
echo "  netdrop add <container>"
echo "  netdrop remove <container>"
echo "  netdrop list"
echo "  netdrop check"
echo "  netdrop show <container>"
echo "  netdrop status <container>"
echo "  netdrop daemon"
echo "  netdrop version"
