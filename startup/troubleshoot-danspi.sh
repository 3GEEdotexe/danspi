#!/usr/bin/env bash
set -u

LOG="$HOME/danspi-debug-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "danspi debug / repair script"
echo "log file: $LOG"
echo "=================================================="

echo
echo "[1] basic system info"
echo "--------------------------------------------------"
date || true
uname -a || true
cat /etc/os-release || true
echo
whoami || true
id || true

echo
echo "[2] disk / memory"
echo "--------------------------------------------------"
df -h || true
free -h || true

echo
echo "[3] network state"
echo "--------------------------------------------------"
ip a || true
ip route || true
nmcli device status || true
nmcli radio all || true
rfkill list || true

echo
echo "[4] apt sources"
echo "--------------------------------------------------"
ls -lah /etc/apt /etc/apt/sources.list.d 2>/dev/null || true
echo
grep -R "^[[:space:]]*deb\|^[[:space:]]*Types:\|^[[:space:]]*URIs:\|^[[:space:]]*Suites:\|^[[:space:]]*Components:" \
  /etc/apt/sources.list /etc/apt/sources.list.d /etc/apt/sources.list.d/*.sources 2>/dev/null || true

echo
echo "[5] held packages"
echo "--------------------------------------------------"
apt-mark showhold || true

echo
echo "[6] key package policy"
echo "--------------------------------------------------"
apt-cache policy libudev1 libudev-dev systemd systemd-timesyncd udev openssh-server python3 gcc g++ || true

echo
echo "[7] dpkg audit"
echo "--------------------------------------------------"
sudo dpkg --audit || true
echo
sudo dpkg -C || true

echo
echo "[8] attempt dpkg repair"
echo "--------------------------------------------------"
sudo dpkg --configure -a || true

echo
echo "[9] refresh apt metadata"
echo "--------------------------------------------------"
sudo apt-get clean || true
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update || true

echo
echo "[10] attempt broken-dependency repair"
echo "--------------------------------------------------"
sudo apt-get -o Dpkg::Use-Pty=0 -f install -y || true

echo
echo "[11] dpkg audit after repair"
echo "--------------------------------------------------"
sudo dpkg --audit || true
echo
sudo dpkg -C || true

echo
echo "[12] ssh package / service status"
echo "--------------------------------------------------"
dpkg -l | grep -E 'openssh-server|openssh-client' || true
echo
systemctl status ssh --no-pager || true
echo
sudo systemctl enable --now ssh || true
echo
systemctl status ssh --no-pager || true

echo
echo "[13] package manager logs"
echo "--------------------------------------------------"
tail -n 80 /var/log/dpkg.log 2>/dev/null || true
echo
tail -n 80 /var/log/apt/history.log 2>/dev/null || true
echo
tail -n 80 /var/log/apt/term.log 2>/dev/null || true

echo
echo "=================================================="
echo "done"
echo "saved log to: $LOG"
echo "=================================================="
