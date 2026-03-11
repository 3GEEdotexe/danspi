```bash
#!/usr/bin/env bash

set -euo pipefail

LOG="$HOME/force_fix_ssh_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "Force-fix Ubuntu sources and install SSH"
echo "=================================================="
echo "Log: $LOG"
echo

step() {
    echo
    echo "--------------------------------------------------"
    echo "$1"
    echo "--------------------------------------------------"
}

step "1) Show current repo file BEFORE changes"
sudo cat /etc/apt/sources.list.d/ubuntu.sources || true

step "2) Back up current repo file"
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak

step "3) Force overwrite repo file with correct contents"
sudo bash -c 'cat > /etc/apt/sources.list.d/ubuntu.sources << "EOF"
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF'

step "4) Show repo file AFTER changes"
sudo cat /etc/apt/sources.list.d/ubuntu.sources

step "5) Verify expected Suites line exists"
grep -q '^Suites: noble noble-updates noble-backports$' /etc/apt/sources.list.d/ubuntu.sources

step "6) Clear apt metadata"
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/apt/archives/partial/*

step "7) Update package lists"
sudo apt update

step "8) Show OpenSSH versions after repo fix"
apt-cache policy openssh-server openssh-client openssh-sftp-server
apt-cache madison openssh-server openssh-client openssh-sftp-server

step "9) Remove stale debconf/dpkg locks only if no package process is running"
PKG_PROCS="$(ps -ef | grep -E 'apt|dpkg|debconf|unattended|packagekit|ubiquity' | grep -v grep || true)"
if [ -z "$PKG_PROCS" ]; then
    echo "No active package processes detected."
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo rm -f /var/cache/debconf/config.dat-lock
else
    echo "Active package-related processes detected:"
    echo "$PKG_PROCS"
    echo "Not removing locks."
fi

step "10) Reconfigure pending packages"
sudo dpkg --configure -a || true

step "11) Fix broken packages"
sudo apt --fix-broken install -y || true

step "12) Install matching OpenSSH packages"
sudo apt install -y openssh-client openssh-sftp-server openssh-server

step "13) Enable and start SSH"
sudo systemctl enable --now ssh

step "14) Verify SSH status"
sudo systemctl status ssh --no-pager || true
sudo ss -tulpn | grep ':22' || true

step "15) Show IP address"
hostname -I

echo
echo "=================================================="
echo "DONE"
echo "Log saved to: $LOG"
echo "=================================================="
