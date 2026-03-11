#!/usr/bin/env bash

set -euo pipefail

LOG="$HOME/force_clear_debconf_install_ssh_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "Force clear debconf lock and install OpenSSH"
echo "=================================================="
echo "Log: $LOG"
echo

step() {
    echo
    echo "--------------------------------------------------"
    echo "$1"
    echo "--------------------------------------------------"
}

step "1) Show repo file"
sudo cat /etc/apt/sources.list.d/ubuntu.sources || true

step "2) Show package versions"
apt-cache policy openssh-server openssh-client openssh-sftp-server || true

step "3) Show processes that may hold apt/dpkg/debconf locks"
ps -ef | grep -E 'apt|dpkg|debconf|packagekit|unattended|ubiquity|oem|update-manager' | grep -v grep || true

echo
echo "Open files on debconf/db locks:"
sudo lsof /var/cache/debconf/config.dat || true
sudo lsof /var/cache/debconf/config.dat-lock || true
sudo lsof /var/lib/dpkg/lock || true
sudo lsof /var/lib/dpkg/lock-frontend || true

step "4) Stop background package services"
sudo systemctl stop packagekit.service 2>/dev/null || true
sudo systemctl stop packagekit-offline-update.service 2>/dev/null || true
sudo systemctl stop apt-daily.service 2>/dev/null || true
sudo systemctl stop apt-daily-upgrade.service 2>/dev/null || true
sudo systemctl stop unattended-upgrades.service 2>/dev/null || true

step "5) Kill known lock holders if they are running"
sudo pkill -9 -f packagekit || true
sudo pkill -9 -f apt || true
sudo pkill -9 -f dpkg || true
sudo pkill -9 -f debconf || true
sudo pkill -9 -f unattended || true
sudo pkill -9 -f update-manager || true

echo
echo "NOTE:"
echo "If you see 'ubiquity' or OEM first-boot setup in the process list above,"
echo "close/finish that UI before continuing. This script does not kill ubiquity."

sleep 2

step "6) Remove stale lock files"
sudo rm -f /var/cache/debconf/config.dat-lock
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/dpkg/lock-frontend

step "7) Reconfigure package database"
sudo dpkg --configure -a || true

step "8) Fix broken packages"
sudo env DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y || true

step "9) Install OpenSSH noninteractively"
sudo env DEBIAN_FRONTEND=noninteractive apt install -y openssh-client openssh-sftp-server openssh-server

step "10) Enable SSH"
sudo systemctl enable --now ssh

step "11) Verify"
sudo systemctl status ssh --no-pager || true
sudo ss -tulpn | grep ':22' || true
hostname -I || true

step "12) Tail recent apt term log"
tail -n 120 /var/log/apt/term.log || true

echo
echo "=================================================="
echo "DONE"
echo "Log saved to: $LOG"
echo "=================================================="
