#!/bin/bash
# DNSCrypt-Proxy installer script customized for user ultrAve

set -e

INSTALL_DIR="/opt/dnscrypt-proxy"
SERVICE="dnscrypt-proxy"
UNIT_FILE="/etc/systemd/system/${SERVICE}.service"
CONFIG_REPO="https://github.com/ultrAve/SuperDNS-Retrieval-.git"

log() {
    echo "[INFO] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

check_prerequisites() {
    command -v git >/dev/null || error "git is required but not installed."
    command -v systemctl >/dev/null || error "systemctl is required but not installed."
}

install_dnscrypt() {
    log "Creating install directory $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    
    log "Cloning configuration repo from $CONFIG_REPO..."
    git clone --depth 1 "$CONFIG_REPO" "$INSTALL_DIR/config" || error "Failed to clone config repo."
    
    # Move config file to expected location
    if [[ -f "$INSTALL_DIR/config/dnscrypt-proxy.toml" ]]; then
        mv "$INSTALL_DIR/config/dnscrypt-proxy.toml" "$INSTALL_DIR/dnscrypt-proxy.toml"
    elif [[ -f "$INSTALL_DIR/config/config.yaml" ]]; then
        mv "$INSTALL_DIR/config/config.yaml" "$INSTALL_DIR/dnscrypt-proxy.toml"
    else
        error "No config file found in repo. Expected dnscrypt-proxy.toml or config.yaml."
    fi

    rm -rf "$INSTALL_DIR/config"

    log "Downloading latest dnscrypt-proxy binary..."
    # For demo, download prebuilt linux binary; adjust as needed
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest | grep browser_download_url | grep linux-x86_64 | cut -d '"' -f 4)
    curl -L "$LATEST_RELEASE" -o "$INSTALL_DIR/dnscrypt-proxy.tar.gz"
    tar -xzf "$INSTALL_DIR/dnscrypt-proxy.tar.gz" -C "$INSTALL_DIR" --strip-components=1
    rm "$INSTALL_DIR/dnscrypt-proxy.tar.gz"
    chmod +x "$INSTALL_DIR/dnscrypt-proxy"

    log "Creating systemd service unit..."
    cat > "$UNIT_FILE" <<EOF
[Unit]
Description=DNSCrypt-Proxy client
After=network.target
Documentation=https://github.com/DNSCrypt/dnscrypt-proxy/wiki

[Service]
ExecStart=$INSTALL_DIR/dnscrypt-proxy -config $INSTALL_DIR/dnscrypt-proxy.toml
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=5
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=$INSTALL_DIR
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
SystemCallArchitectures=native
MemoryDenyWriteExecute=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$SERVICE"

    log "Installation complete. dnscrypt-proxy running as a service."
}

main() {
    check_prerequisites
    install_dnscrypt
}

main "$@"
